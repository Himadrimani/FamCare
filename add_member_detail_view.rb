require 'xcodeproj'

project_path = '/Users/mani16/Downloads/ProjectiOS 2/HomeScreen.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'HomeScreen' }
group = project.main_group.find_subpath(File.join('HomeScreen', 'Challenges', 'VCs'), true)
file_ref = group.new_file('ChallengeMemberDetailView.swift')

if !target.source_build_phase.files_references.include?(file_ref)
  target.source_build_phase.add_file_reference(file_ref)
  project.save
  puts "Added ChallengeMemberDetailView.swift to HomeScreen target"
else
  puts "Already exists"
end
