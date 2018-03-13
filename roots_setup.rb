require 'optparse'
require 'find'
require 'active_support/all'

module Tools
  def self.in_project(command, folder = nil, action = nil)
    folder = "cd #{folder} && " if folder
    puts action.present? ? "** running: #{action}" : "** running: #{command}"
    system "#{folder}#{command}"
  end

  def self.rename_placeholders_by_directory(directory, from, to, from_to)
    Find.find("#{directory}") do |file_name|
      next unless File.file?(file_name)
      rename_placeholders_by_file(file_name, from, to, from_to)
    end
  end

  def self.rename_placeholders_by_file(file_name, from, to, from_to = nil)
    raise "#{file_name} not a file" unless File.file?(file_name)
    if from_to.nil?
      overwite_file(file_name, from, to)
    else
      from_to.each do |ft|
        overwite_file(file_name, ft[0], ft[1])
      end
    end
  end

  def self.overwite_file(file_name, from, to)
    file_name = "#{file_name}"
    replace = File.read(file_name).gsub(from, to)
    File.open(file_name, 'w') { |file| file.puts replace }
  end

  def self.generate_salts_and_pws_by_directory(directory)
    Find.find("#{directory}") do |file_name|
      next unless File.file?(file_name)
      generate_salts_and_pws_by_file(file_name)
    end
  end

  PLACEHOLDERS = { 'generateme' => 64, 'example_dbpassword' => 15,
                   'stagingpw' => 15, 'productionpw' => 15,
                   'example_password' => 15 }.freeze

  def self.generate_salts_and_pws_by_file(file_name)
    raise "#{file_name} not a file" unless File.file?(file_name)
    replace = ''
    line_replaced = false
    File.readlines(file_name).each do |line|
      PLACEHOLDERS.each do |placeholder, length|
        if line.include? placeholder
          line_replaced = true
          replace << line.gsub(placeholder, SecureRandom.base64(length))
        end
      end
      replace << line unless line_replaced
      line_replaced = false
    end
    File.open(file_name, 'w') { |file| file.puts replace }
  end
end

# This will hold the options we parse

final_msg = []
$opts = {}

OptionParser.new do |parser|
  parser.banner = 'Usage: wordpress_setup.rb [options]'

  parser.on('-h', '--help', 'Show this help message') do |_v|
    puts parser
  end

  parser.on('-s', '--site-url=URL', 'The url of the client site address eg "coolproject.com"') do |v|
    ['www.', 'http://', 'https://'].map { |remove| v.gsub!(remove,'') }
    $opts[:proj_url] = v
    raise 'must include top level domain (.com/.co.uk)' unless v.include?('.')
    $opts[:proj] = $opts[:proj_url].split('.').first
  end

  parser.on('-o', '--organisation-url=URL', 'your organisations url name eg "websprung.com"') do |v|
    ['www.', 'http://', 'https://'].map { |remove| v.gsub!(remove,'') }
    $opts[:org_url] = v
    raise 'must include top level domain (.com/.co.uk)' unless v.include?('.')
    $opts[:org] = $opts[:org_url].split('.').first
  end

  parser.on('-p', '--mail-password=PASSWORD', 'mail password (leave blank to have one auto generated)') do |v|
    $opts[:mp] = v
  end

  parser.on('-m', '--mail-service=SERVICE', 'transactional email service can be: "mailgun", "sendgrid" (defaults to: mailgun)') do |v|
    case $opts[:ms] = v
    when 'mailgun'
      $opts[:mss] = 'mg.' # mailservice subdomain
    when 'sendgrid'
      $opts[:mss] = 'sg.'
    else
      raise "-m, --mail-service must be 'mailgun', 'sendgrid' or left blank"
    end
  end

  parser.on('-a', '--acf-key=KEY', 'OPTIONAL Advanced Custom Fields license key if available. Leave blank to skip this part of setup') do |v|
    $opts[:acf] = v
  end

  parser.on('-t', '--roots-repo=USERNAME', 'OPTIONAL alternative repository to pull trellis + bedrock from. defaults to "roots"') do |v|
    $opts[:roots] = v
  end

  parser.on('-g', '--github-usernames=foo,bar', 'OPTIONAL github usernames comma seperated to retrieve public keys (will default to local public keys if left blank).') do |v|
    $opts[:gpk] = v
  end

  parser.on('-r', '--repo=REPO', 'OPTIONAL select remote repository. will setup remote using organisation name. leave blank to skip. can be "bitbucket" or "github"') do |v|
    $opts[:repo_service] = v
    case $opts[:repo_service]
    when 'bitbucket'
      $opts[:repo] = 'git@bitbucket.org'
    when 'github'
      $opts[:repo] = 'git@github.com'
    else
      raise "-r, --repo must be 'bitbucket', 'github' or left blank"
    end
  end

end.parse!

unless $opts[:ms].present?
  $opts[:ms]  = 'mailgun'.freeze
  $opts[:mss] = 'mg.'.freeze
end

$opts[:roots] = 'roots'.freeze unless $opts[:roots].present?

$opts[:mp] = SecureRandom.base64(12) unless $opts[:mp].present?
mail_message = "Setup a new user in the #{$opts[:org]} #{$opts[:ms]} dashboard\n"
mail_message << "for mailgun: https://app.mailgun.com/app/domains/#{$opts[:mss]}#{$opts[:org_url]}/credentials\n"
mail_message << "** user\n#{$opts[:proj]}@#{$opts[:mss]}#{$opts[:org_url]}\n"
mail_message << "** password\n#{$opts[:mp]}"
final_msg << mail_message

if [$opts[:proj], $opts[:org]].any?(&:nil?)
  puts 'vars missing'
  exit(1)
end

# make proj directory
system "mkdir ../#{$opts[:proj_url]}"
if $?.exitstatus > 0
  puts "failed to mkdir #{$opts[:proj_url]}"
  exit(1)
end

# now set this as the file path, storing our current path for later ref
CURRENT_PATH = Dir.pwd
Dir.chdir "../#{$opts[:proj_url]}"

# clone trellis
Tools.in_project("git clone --depth=1 git@github.com:#{$opts[:roots]}/trellis.git && rm -rf trellis/.git")
if $?.exitstatus > 0
  puts 'failed to clone trellis'
  exit(1)
end

# clone bedrock
Tools.in_project("git clone --depth=1 git@github.com:#{$opts[:roots]}/bedrock.git site && rm -rf site/.git")
if $?.exitstatus > 0
  puts 'failed to clone bedrock'
  exit(1)
end

# copy over README
if File.exists?("#{CURRENT_PATH}/readme_template.md")
  puts '** copying readme over'
  f = File.new("README.md", 'w+')
  f.write(File.read("#{CURRENT_PATH}/readme_template.md"))
  f.close
end

# overwite 'generateme' and pw strings in vaults files
puts '** generating salts and pws'
Tools.generate_salts_and_pws_by_directory("trellis/group_vars/")

puts "** overwriting #{$opts[:proj_url]}/trellis/group_vars/all/mail.yml"

Tools.rename_placeholders_by_file("trellis/group_vars/all/mail.yml", nil, nil,
                                  [[/smtp.example.com:587/, "smtp.#{$opts[:ms]}.com:587"],
                                   [/admin@example.com/, "#{$opts[:proj]}@#{$opts[:mss]}#{$opts[:org_url]}"],
                                   [/smtp_user/, "#{$opts[:proj]}@#{$opts[:mss]}#{$opts[:org_url]}"]])

puts "** overwriting #{$opts[:proj_url]}/trellis/group_vars"

public_keys = if $opts[:gpk].present?
                ['      # - https://github.com/username.keys',
                 $opts[:gpk].split(',').map do |_name|
                   "      - https://github.com/#{_name}.keys"
                 end.join("\n")]
              else
                ['# - https://github.com/username.keys', '# - https://github.com/username.keys']
end

Tools.rename_placeholders_by_directory("trellis/group_vars/", nil, nil,
                                       [['git@github.com:example/example.com.git', "git@#{$opts[:repo_service]}.com:#{$opts[:org]}/#{$opts[:proj_url]}.git"],
                                        [/example.com/, $opts[:proj_url]],
                                        [/example./, "#{$opts[:proj]}."],
                                        ['sshd_password_authentication: false', 'sshd_password_authentication: true'],
                                        public_keys,
                                        ['smtp_password', $opts[:mp]]])

puts "** overwriting #{$opts[:proj_url]}/trellis/hosts/"

Tools.rename_placeholders_by_file("trellis/hosts/staging",
                                  /your_server_hostname/, "#{$opts[:proj]}.#{$opts[:org_url]}")

Tools.rename_placeholders_by_file("trellis/hosts/production",
                                  /your_server_hostname/, $opts[:proj_url])

if $opts[:acf].present?
  puts '** Adding ACF Key'
  File.open("trellis/group_vars/all/vault.yml", 'a') do |f|
    f << "acf_pro_key: #{$opts[:acf]}\n"
  end
  File.open("trellis/group_vars/staging/vault.yml", 'a') do |f|
    f << "      acf_pro_key: #{$opts[:acf]}\n"
  end
  File.open("trellis/group_vars/production/vault.yml", 'a') do |f|
    f << "      acf_pro_key: #{$opts[:acf]}\n"
  end
end

puts '** creating vault pass'
# create .vault_pass
f = File.new("trellis/.vault_pass", 'w+')
f.write(SecureRandom.base64(15))
f.close

# install ansible requirements
Tools.in_project('ansible-galaxy install -r requirements.yml', 'trellis')
if $?.exitstatus > 0
  puts 'failed to run ansible'
  exit(1)
end

Tools.in_project('ansible-vault encrypt group_vars/all/vault.yml && ansible-vault encrypt group_vars/staging/vault.yml && ansible-vault encrypt group_vars/production/vault.yml',
                 'trellis',
                 'ansible encrypt in all vault files')
if $?.exitstatus > 0
  puts 'failed to run ansible encrypt'
  exit(1)
end

if $opts[:repo].present?
  Tools.in_project('git init')
  Tools.in_project("git remote add origin #{$opts[:repo]}:#{$opts[:org]}/#{$opts[:proj_url]}.git")
  Tools.in_project("git add . && git commit -m 'initial commit'")
  if $?.exitstatus > 0
    puts 'failed to initialise git'
    exit(1)
  end
end

final_msg << "cd into trellis and run 'vagrant up'\ncd into site and run 'composer up'\ninstall a theme (see github.com/roots/sage)"
puts "\n\n** done!!!\n** next steps:"
final_msg.each do |msg|
  puts msg
  puts "\n\n"
end
