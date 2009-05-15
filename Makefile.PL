use inc::Module::Install;

# Define metadata
name           'XML-Easy-Transform';
all_from       'lib/XML/Easy/Transform.pm';

requires       'Data::Easy'  => '0.002';
test_requires  'Test::More'  => '0';

license 'perl';

WriteAll;
