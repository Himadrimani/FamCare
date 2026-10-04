#!/usr/bin/env ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('HomeScreen.xcodeproj')

# Add ChallengeActivityAttributes.swift and ChallengeActivityManager.swift to the main app target
main_target = project.targets.find { |t| t.name == 'HomeScreen' }
model_group = project.main_group.find_subpath('HomeScreen/Model', false)

['ChallengeActivityAttributes.swift', 'ChallengeActivityManager.swift'].each do |filename|
  existing = model_group.files.find { |f| f.path == filename || f.name == filename }
  unless existing
    file_ref = model_group.new_file(filename)
    main_target.source_build_phase.add_file_reference(file_ref)
    puts "Added #{filename} to HomeScreen target"
  end
end

# Add ChallengeActivityAttributes.swift and ChallengeLiveActivityView.swift to the widget target
widget_target = project.targets.find { |t| t.name == 'FamCareWidgetExtension' }
widget_group = project.main_group.find_subpath('FamCareWidget', false)

['ChallengeActivityAttributes.swift', 'ChallengeLiveActivityView.swift'].each do |filename|
  existing = widget_group.files.find { |f| f.path == filename || f.name == filename }
  unless existing
    file_ref = widget_group.new_file(filename)
    widget_target.source_build_phase.add_file_reference(file_ref)
    puts "Added #{filename} to FamCareWidgetExtension target"
  end
end

project.save
puts "Done."
