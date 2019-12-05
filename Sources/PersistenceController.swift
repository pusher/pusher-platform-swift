import Foundation
import CoreData

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public class PersistenceController {
    
    // MARK: - Types
    
    public typealias CompletionHandler = (Error?) -> Void
    public typealias BackgroundTask = (NSManagedObjectContext) -> Void
    
    // MARK: - Properties
    
    public let model: NSManagedObjectModel
    public let storeCoordinator: NSPersistentStoreCoordinator
    
    private let privateContext: NSManagedObjectContext
    public let mainContext: NSManagedObjectContext
    
    public let logger: PPLogger?
    
    public var shouldSaveWhenApplicationWillResignActive: Bool
    public var shouldSaveWhenApplicationDidEnterBackground: Bool
    public var shouldSaveWhenApplicationWillTerminate: Bool
    
    // MARK: - Initializers
    
    public init(model: NSManagedObjectModel, storeDescriptions: [NSPersistentStoreDescription], logger: PPLogger? = nil, storesInitializationCompletionHandler: CompletionHandler? = nil) throws {
        self.logger = logger
        
        guard storeDescriptions.count > 0 else {
            self.logger?.log("At least one persistent store description is required to instantiated PersistenceController.", logLevel: .error)
            throw PersistenceError.persistentStoreDescriptionMissing
        }
        
        self.model = model
        self.storeCoordinator = NSPersistentStoreCoordinator(managedObjectModel: self.model)
        
        self.privateContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        self.privateContext.mergePolicy = NSMergePolicy.mergeByPropertyStoreTrump
        self.privateContext.persistentStoreCoordinator = self.storeCoordinator
        self.privateContext.name = "Pusher Private Context"
        
        self.mainContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        self.mainContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        self.mainContext.parent = self.privateContext
        self.mainContext.name = "Pusher Main Context"
        
        self.shouldSaveWhenApplicationWillResignActive = false
        self.shouldSaveWhenApplicationDidEnterBackground = true
        self.shouldSaveWhenApplicationWillTerminate = true
        
        registerForApplicationLifecycleNotifications()
        addStores(for: storeDescriptions, completionHandler: storesInitializationCompletionHandler)
    }
    
    public convenience init(storeDescriptions: [NSPersistentStoreDescription], logger: PPLogger? = nil, storesInitializationCompletionHandler: CompletionHandler? = nil) throws {
        guard let model = NSManagedObjectModel.mergedModel(from: nil) else {
            logger?.log("Failed to locate object model in the main bundle.", logLevel: .error)
            throw PersistenceError.objectModelNotFound
        }
        
        try self.init(model: model, storeDescriptions: storeDescriptions, logger: logger, storesInitializationCompletionHandler: storesInitializationCompletionHandler)
    }
    
    // MARK: - Public methods
    
    public func performBackgroundTask(_ backgroundTask: @escaping BackgroundTask) {
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.mergePolicy = NSMergePolicy.mergeByPropertyStoreTrump
        context.parent = mainContext
        context.name = "Pusher Background Task Context"
        
        context.perform {
            autoreleasepool {
                backgroundTask(context)
            }
        }
    }
    
    public func save(completionHandler: CompletionHandler? = nil) {
        mainContext.save(shouldWait: true) { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                self.logger?.log("Failed to save main context with error: \(error.localizedDescription)", logLevel: .warning)
                
                if let completionHandler = completionHandler {
                    completionHandler(error)
                }
            }
            else {
                self.privateContext.save(shouldWait: false) { [weak self] error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        self.logger?.log("Failed to save to persistent stores with error: \(error.localizedDescription)", logLevel: .warning)
                        
                        if let completionHandler = completionHandler {
                            DispatchQueue.main.async {
                                completionHandler(error)
                            }
                        }
                    }
                    else if let completionHandler = completionHandler {
                        DispatchQueue.main.async {
                            completionHandler(error)
                        }
                    }
                }
            }
        }
    }
    
    public func save(includingBackgroundTaskContext backgroundTaskContext: NSManagedObjectContext, completionHandler: CompletionHandler? = nil) {
        backgroundTaskContext.save(shouldWait: true) { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                self.logger?.log("Failed to save background task context with error: \(error.localizedDescription)", logLevel: .warning)
                
                if let completionHandler = completionHandler {
                    DispatchQueue.main.async {
                        completionHandler(error)
                    }
                }
            }
            else {
                self.save(completionHandler: completionHandler)
            }
        }
    }
    
    // MARK: - Private methods
    
    private func addStores(for storeDescriptions: [NSPersistentStoreDescription], completionHandler: CompletionHandler?) {
        if storeDescriptions.count == 0 {
            if let completionHandler = completionHandler {
                completionHandler(nil)
            }
            
            return
        }
        
        var mutableStoreDescriptions = storeDescriptions
        let storeDescription = mutableStoreDescriptions.removeLast()
        
        addStore(for: storeDescription, shouldAttemptRecovery: true) { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                self.logger?.log("Failed to add to persistent stores with error: \(error.localizedDescription)", logLevel: .warning)
                
                if let completionHandler = completionHandler {
                    completionHandler(error)
                }
            }
            else {
                self.addStores(for: mutableStoreDescriptions, completionHandler: completionHandler)
            }
        }
    }
    
    private func addStore(for storeDescription: NSPersistentStoreDescription, shouldAttemptRecovery: Bool, completionHandler: CompletionHandler?) {
        storeCoordinator.addPersistentStore(with: storeDescription) { [weak self] _, error in
            guard let self = self else { return }
            
            if error != nil, shouldAttemptRecovery {
                storeDescription.attemptRecovery()
                self.addStore(for: storeDescription, shouldAttemptRecovery: false, completionHandler: completionHandler)
            }
            else if let completionHandler = completionHandler {
                completionHandler(error)
            }
        }
    }
    
    private func registerForApplicationLifecycleNotifications() {
        // Lifecycle notifications for watchOS are not supported.
        
        let notificationCenter = NotificationCenter.default
        
        #if os(iOS) || os(tvOS)
        notificationCenter.addObserver(self, selector: #selector(applicationWillResignActive(notfication:)), name: UIApplication.willResignActiveNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(applicationDidEnterBackground(notfication:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(applicationWillTerminate(notfication:)), name: UIApplication.willTerminateNotification, object: nil)
        #elseif os(OSX)
        notificationCenter.addObserver(self, selector: #selector(applicationWillResignActive(notfication:)), name: NSApplication.willResignActiveNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(applicationDidEnterBackground(notfication:)), name: NSApplication.didHideNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(applicationWillTerminate(notfication:)), name: NSApplication.willTerminateNotification, object: nil)
        #endif
    }
    
    // MARK: - Notifications
    
    @objc private func applicationWillResignActive(notfication: NSNotification) {
        if shouldSaveWhenApplicationWillResignActive {
            save()
        }
    }
    
    @objc private func applicationDidEnterBackground(notfication: NSNotification) {
        if shouldSaveWhenApplicationDidEnterBackground {
            save()
        }
    }
    
    @objc private func applicationWillTerminate(notfication: NSNotification) {
        if shouldSaveWhenApplicationWillTerminate {
            save()
        }
    }
    
}
