#!/usr/bin/env ruby
# add_widget_data_provider.rb
#
# Adds WidgetDataProvider.swift to the main HomeScreen target.
# Run after creating the file.

require 'xcodeproj'

PROJECT_PATH = 'HomeScreen.xcodeproj'
project = Xcodeproj::Project.open(PROJECT_PATH)
target = project.targets.find { |t| t.product_type == 'com.apple.product-type.application' }

model_group = project.main_group.find_subpath(File.join('HomeScreen', 'Model'), false)
abort("Model group not found") unless model_group

filename = 'WidgetDataProvider.swift'
existing = model_group.files.find { |f| f.path == filename || f.name == filename }

if existing
  puts "File already in group: #{filename}"
  unless target.source_build_phase.files_references.include?(existing)
    target.source_build_phase.add_file_reference(existing)
    puts "Added to target"
  end
else
  file_ref = model_group.new_file(filename)
  target.source_build_phase.add_file_reference(file_ref)
  puts "Added #{filename} to Model group and main target"
end

project.save
puts "✅ Done"
