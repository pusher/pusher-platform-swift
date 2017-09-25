#!/bin/bash

chruby 2.4.1
bundle install  
bundle exec danger --fail-on-errors=true  
