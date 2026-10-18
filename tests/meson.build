domain_tests = executable('domain-tests', domain_sources, 'unit/domain-tests.vala', dependencies: domain_deps)
test('domain', domain_tests)
threat_tests=executable('threat-tests',domain_sources,'unit/threat-tests.vala',dependencies:domain_deps)
test('threat-protection',threat_tests)
