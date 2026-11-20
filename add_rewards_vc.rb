require 'xcodeproj'
project_path = 'HomeScreen.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'HomeScreen' } || project.targets.first

group = project.main_group.find_subpath(File.join('HomeScreen', 'Challenges', 'VCs'), false)
if group.nil?
  puts "Group not found"
else
  existing = group.files.find { |f| f.path == 'RewardsViewController.swift' || f.name == 'RewardsViewController.swift' }
  if existing
    puts "File already in group"
    unless target.source_build_phase.files_references.include?(existing)
      target.source_build_phase.add_file_reference(existing)
      puts "Added to target"
    end
  else
    file_ref = group.new_file('RewardsViewController.swift')
    target.source_build_phase.add_file_reference(file_ref)
    puts "Added file to group and target"
  end
  project.save
end
