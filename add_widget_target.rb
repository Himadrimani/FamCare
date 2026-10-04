#!/usr/bin/env ruby
# add_widget_target.rb
#
# Adds the FamCareWidget extension target to the Xcode project,
# registers all Swift source files, sets up the entitlements,
# and configures it as an app extension embedded in the main app.
#
# Usage: ruby add_widget_target.rb

require 'xcodeproj'

PROJECT_PATH     = 'HomeScreen.xcodeproj'
WIDGET_DIR       = 'FamCareWidget'
WIDGET_TARGET    = 'FamCareWidgetExtension'
MAIN_BUNDLE_ID   = 'com.namanmittal.famcare'
WIDGET_BUNDLE_ID = "#{MAIN_BUNDLE_ID}.widget"
APP_GROUP        = 'group.com.namanmittal.famcare'

project = Xcodeproj::Project.open(PROJECT_PATH)
main_target = project.targets.find { |t| t.product_type == 'com.apple.product-type.application' }

abort("Main app target not found!") unless main_target

# Check if widget target already exists
existing = project.targets.find { |t| t.name == WIDGET_TARGET }
if existing
  puts "Widget target '#{WIDGET_TARGET}' already exists. Skipping creation."
  exit 0
end

puts "Creating widget extension target: #{WIDGET_TARGET}"

# 1. Create the widget extension target
widget_target = project.new_target(
  :app_extension,
  WIDGET_TARGET,
  :ios,
  '17.0'
)

# 2. Create or find the FamCareWidget group
widget_group = project.main_group.find_subpath(WIDGET_DIR, false)
if widget_group.nil?
  widget_group = project.main_group.new_group(WIDGET_DIR, WIDGET_DIR)
  puts "  Created group: #{WIDGET_DIR}"
end

# 3. Add all Swift files from the widget directory
swift_files = Dir.glob(File.join(WIDGET_DIR, '*.swift'))
swift_files.each do |path|
  filename = File.basename(path)
  existing_ref = widget_group.files.find { |f| f.path == filename || f.name == filename }
  
  if existing_ref
    puts "  File already in group: #{filename}"
    unless widget_target.source_build_phase.files_references.include?(existing_ref)
      widget_target.source_build_phase.add_file_reference(existing_ref)
      puts "    Added to target build phase"
    end
  else
    file_ref = widget_group.new_file(filename)
    widget_target.source_build_phase.add_file_reference(file_ref)
    puts "  Added: #{filename}"
  end
end

# 4. Add the entitlements file
entitlements_path = File.join(WIDGET_DIR, 'FamCareWidget.entitlements')
if File.exist?(entitlements_path)
  ent_ref = widget_group.files.find { |f| f.path == 'FamCareWidget.entitlements' }
  unless ent_ref
    ent_ref = widget_group.new_file('FamCareWidget.entitlements')
    puts "  Added entitlements file"
  end
end

# 5. Configure build settings for all configurations
widget_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER']      = WIDGET_BUNDLE_ID
  config.build_settings['PRODUCT_NAME']                    = '$(TARGET_NAME)'
  config.build_settings['SWIFT_VERSION']                   = '5.0'
  config.build_settings['TARGETED_DEVICE_FAMILY']          = '1,2'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET']      = '17.0'
  config.build_settings['CODE_SIGN_ENTITLEMENTS']          = "#{WIDGET_DIR}/FamCareWidget.entitlements"
  config.build_settings['INFOPLIST_KEY_CFBundleDisplayName'] = 'FamCare Widget'
  config.build_settings['INFOPLIST_KEY_NSHumanReadableCopyright'] = ''
  config.build_settings['GENERATE_INFOPLIST_FILE']         = 'YES'
  config.build_settings['CURRENT_PROJECT_VERSION']         = '1'
  config.build_settings['MARKETING_VERSION']               = '1.0'
  config.build_settings['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
  config.build_settings['ASSETCATALOG_COMPILER_WIDGET_BACKGROUND_COLOR_NAME'] = 'WidgetBackground'
  config.build_settings['SKIP_INSTALL']                    = 'YES'
  config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = [
    '$(inherited)',
    '@executable_path/Frameworks',
    '@executable_path/../../Frameworks'
  ]
end

# 6. Add the widget as an embedded extension of the main app
main_target.add_dependency(widget_target)

# Create the "Embed App Extensions" copy phase if it doesn't exist
embed_phase = main_target.copy_files_build_phases.find { |p| p.name == 'Embed App Extensions' }
unless embed_phase
  embed_phase = main_target.new_copy_files_build_phase('Embed App Extensions')
  embed_phase.dst_subfolder_spec = '13'  # Plugins folder for extensions
end

# Add widget product to the embed phase
widget_product = widget_target.product_reference
unless embed_phase.files_references.include?(widget_product)
  build_file = embed_phase.add_file_reference(widget_product)
  build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
  puts "  Embedded widget extension in main app"
end

# 7. Add frameworks — WidgetKit and SwiftUI
['WidgetKit.framework', 'SwiftUI.framework'].each do |fw_name|
  existing_fw = widget_target.frameworks_build_phase.files.find { |f| f.display_name == fw_name }
  unless existing_fw
    fw_ref = project.frameworks_group.new_file(fw_name, :sdk_root)
    widget_target.frameworks_build_phase.add_file_reference(fw_ref)
    puts "  Linked framework: #{fw_name}"
  end
end

# 8. Save
project.save
puts "\n✅ Widget target '#{WIDGET_TARGET}' created and configured successfully!"
puts "   Bundle ID: #{WIDGET_BUNDLE_ID}"
puts "   App Group: #{APP_GROUP}"
puts "\nNext steps:"
puts "  1. Open Xcode and select the FamCareWidgetExtension target"
puts "  2. In Signing & Capabilities, enable 'App Groups' with '#{APP_GROUP}'"
puts "  3. Also enable 'App Groups' on the main HomeScreen target if not already done"
puts "  4. Build and run!"
