Gem::Specification.new do |s|

  git_files = `git ls-files`.split("\n")

  s.name             = 'md-ruby-eval'
  s.version          = File.read(File.join(__dir__, 'VERSION'))
  s.date             = Time.now.strftime('%Y-%m-%d')
  s.summary          = 'Evaluator of Ruby examples in Markdown files.'
  s.authors          = ['Petr Chalupa']
  s.email            = 'git+md-ruby-eval@pitr.ch'
  s.homepage         = 'https://github.com/pitr-ch/md-ruby-eval'
  s.files            = Dir['lib/**/*.rb'] & git_files
  s.extra_rdoc_files = %w(LICENSE.txt README.md VERSION) & git_files
  s.license          = 'Apache-2.0'

  s.bindir = 'bin'
  s.executables << 'md-ruby-eval'
end

