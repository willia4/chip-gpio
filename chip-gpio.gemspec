
Gem::Specification.new do |s|
  s.name        = 'chip-gpio'
  s.version     = '0.2.0'
  s.date        = '2017-01-22'
  s.homepage    = 'http://github.com/willia4/chip-gpio'
  s.summary     = "A ruby gem to control the IO hardware on the CHIP computer"
  s.description = "A ruby gem to control the IO hardware the CHIP computer"
  s.authors     = ['James Williams']
  s.email       = 'james@jameswilliams.me'
  s.license     = 'MIT'
  s.files       = Dir.glob("{lib}/**/*") + %w(README.md)

  s.add_runtime_dependency 'epoll'
end