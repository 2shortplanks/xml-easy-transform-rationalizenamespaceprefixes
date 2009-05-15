use inc::Module::Install;

# Define metadata
name           'XML-Easy-Transform-RationalizeNamespacePrefixes';
all_from       'lib/XML/Easy/Transform/RationalizeNamespacePrefixes.pm';

requires       'Data::Easy'  => '0.002';
test_requires  'Test::More'  => '0';

license 'perl';

WriteAll;
