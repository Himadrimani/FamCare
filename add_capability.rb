require 'xcodeproj'
project_path = 'HomeScreen.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# Check if TargetAttributes exists
attr = project.root_object.attributes['TargetAttributes'] || {}
target_attr = attr[target.uuid] || {}
sys_cap = target_attr['SystemCapabilities'] || {}
sys_cap['com.apple.SignInWithApple'] = { 'enabled' => 1 }
target_attr['SystemCapabilities'] = sys_cap
attr[target.uuid] = target_attr
project.root_object.attributes['TargetAttributes'] = attr

project.save
