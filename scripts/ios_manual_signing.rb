# Runner 타깃의 Release/Profile 설정을 수동 서명으로 바꾼다 (CI 전용, 커밋하지 않음).
# 사용법: ruby scripts/ios_manual_signing.rb ios/Runner.xcodeproj TEAM_ID "프로파일 이름"
require 'xcodeproj'

project_path, team_id, profile_name = ARGV
abort 'usage: ios_manual_signing.rb PROJECT TEAM_ID PROFILE_NAME' unless profile_name

project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'Runner' } or abort 'Runner 타깃이 없습니다'

target.build_configurations.each do |config|
  next if config.name == 'Debug'
  s = config.build_settings
  s['CODE_SIGN_STYLE'] = 'Manual'
  s['DEVELOPMENT_TEAM'] = team_id
  s['CODE_SIGN_IDENTITY'] = 'Apple Distribution'
  s['CODE_SIGN_IDENTITY[sdk=iphoneos*]'] = 'Apple Distribution'
  s['PROVISIONING_PROFILE_SPECIFIER'] = profile_name
  s.delete('PROVISIONING_PROFILE')
  puts "#{config.name}: Manual / #{team_id} / #{profile_name}"
end

project.save
