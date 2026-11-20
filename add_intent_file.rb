#!/usr/bin/env ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('HomeScreen.xcodeproj')
target = project.targets.find { |t| t.name == 'FamCareWidgetExtension' }

widget_group = project.main_group.find_subpath('FamCareWidget', false)

filename = 'SelectMemberIntent.swift'
file_ref = widget_group.files.find { |f| f.path == filename || f.name == filename }

unless file_ref
  file_ref = widget_group.new_file(filename)
  target.source_build_phase.add_file_reference(file_ref)
  puts "Added #{filename} to widget target"
end

project.save
