#!/usr/bin/env ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('HomeScreen.xcodeproj')
widget_target = project.targets.find { |t| t.name == 'FamCareWidgetExtension' }

if widget_target
  widget_target.build_configurations.each do |config|
    config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
    config.build_settings['INFOPLIST_FILE'] = 'FamCareWidget/Info.plist'
  end
  project.save
  puts "Updated Info.plist settings for Widget"
else
  puts "Widget target not found"
end
