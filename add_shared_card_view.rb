require 'xcodeproj'

project_path = 'HomeScreen.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'HomeScreen' }

group = project.main_group.find_subpath('HomeScreen/Messages/Views', true)

file_path = 'HomeScreen/Messages/Views/SharedCardView.swift'
file_ref = group.new_reference(file_path)

target.add_file_references([file_ref])

project.save
puts "Successfully added #{file_path} to HomeScreen target"
