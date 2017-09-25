set -o pipefail

echo Destination: iPhone X
xcodebuild -scheme PusherPlatform -destination "name=iPhone X" test | xcpretty
echo Destination: Apple Watch Series 3 - 42mm
xcodebuild -scheme PusherPlatform -destination "name=Apple Watch Series 3 - 42mm" test | xcpretty
echo Destination: Apple TV 4K
xcodebuild -scheme PusherPlatform -destination "name=Apple TV 4K" test | xcpretty
echo Destination: macOS
xcodebuild -scheme PusherPlatform -destination "platform=macOS" test | xcpretty
