#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 16;

use XML::Easy::Text qw(xml10_read_document xml10_write_element);
use XML::Easy::Transform::RationalizeNamespacePrefixes qw(
   rationalize_namespace_prefixes
);

sub process($) {
  return xml10_write_element(
    rationalize_namespace_prefixes(
      xml10_read_document( $_[0] )
    ),
  );
}

sub chompp($) {
  my $thingy = shift;
  chomp $thingy;
  return $thingy;
}

is process <<'XML', chompp <<'XML', "move up";
<foo>
  <ex1:bar xmlns:ex1="http://www.photobox.com/namespace/example1" />
</foo>
XML
<foo xmlns:ex1="http://www.photobox.com/namespace/example1">
  <ex1:bar/>
</foo>
XML

is process <<'XML', chompp <<'XML', "default";
<foo>
  <bar xmlns="http://www.photobox.com/namespace/example1">
    <bazz zing="zang">
      <buzz xmlns="http://www.photobox.com/namespace/example2"/>
    </bazz>
  </bar>
</foo>
XML
<foo xmlns:default2="http://www.photobox.com/namespace/example1" xmlns:default3="http://www.photobox.com/namespace/example2">
  <default2:bar>
    <default2:bazz zing="zang">
      <default3:buzz/>
    </default2:bazz>
  </default2:bar>
</foo>
XML

is process <<'XML', chompp <<'XML', "muppet";
<muppet:kermit xmlns:muppet="http://www.photobox.com/namespace/example/muppetshow" >
  <muppet:kermit xmlns:muppet="http://www.photobox.com/namespace/example/seasmestreet"/>
</muppet:kermit>
XML
<muppet:kermit xmlns:muppet="http://www.photobox.com/namespace/example/muppetshow" xmlns:muppet2="http://www.photobox.com/namespace/example/seasmestreet">
  <muppet2:kermit/>
</muppet:kermit>
XML

is process <<'XML', chompp <<'XML', "lost attribute prefix";
<wobble xmlns:ex1="http://www.twoshortplanks.com/namespace/example/1" xmlns:ex1also="http://www.twoshortplanks.com/namespace/example/1">
  <ex1:wibble ex1:jelly="in my tummy" ex1also:yum="yum yum"/>
</wobble>
XML
<wobble xmlns:ex1="http://www.twoshortplanks.com/namespace/example/1">
  <ex1:wibble jelly="in my tummy" yum="yum yum"/>
</wobble>
XML

is process <<'XML', chompp <<'XML', "no prefix in on attribute in src";
<a xmlns:ex1="http://www.twoshortplanks.com/namespaces/example/1" xmlns:ex1also="http://www.twoshortplanks.com/namespaces/example/1">
  <ex1:b local="for local people" ex1also:alsolocal="as well"/>
</a>
XML
<a xmlns:ex1="http://www.twoshortplanks.com/namespaces/example/1">
  <ex1:b alsolocal="as well" local="for local people"/>
</a>
XML

is process <<'XML', chompp <<'XML', "no default till later";
<ex1:a xmlns:ex1="http://www.twoshortplanks.com/namespaces/example/1">
  <b xmlns="http://www.twoshortplanks.com/namespaces/example/2"/>
</ex1:a>
XML
<ex1:a xmlns="http://www.twoshortplanks.com/namespaces/example/2" xmlns:ex1="http://www.twoshortplanks.com/namespaces/example/1">
  <b/>
</ex1:a>
XML

is process <<'XML', chompp <<'XML', "multiple prefixes => 1 prefix";
<a>
  <ex3:c xmlns:ex3="http://www.twoshortplanks.com/namespaces/example/3">
     <ex3also:c xmlns:ex3also="http://www.twoshortplanks.com/namespaces/example/3"/>
  </ex3:c>
  <ex3alsoalso:c xmlns:ex3alsoalso="http://www.twoshortplanks.com/namespaces/example/3"/>
</a>
XML
<a xmlns:ex3="http://www.twoshortplanks.com/namespaces/example/3">
  <ex3:c>
     <ex3:c/>
  </ex3:c>
  <ex3:c/>
</a>
XML

is process <<'XML', chompp <<'XML', "multiple overloaded prefixes";
<a>
  <ns:b xmlns:ns="http://www.twoshortplanks.com/namespaces/example/1">
     <ns:c xmlns:ns="http://www.twoshortplanks.com/namespaces/example/2">
       <ns:d />
     </ns:c>
  </ns:b>
  <ns:e xmlns:ns="http://www.twoshortplanks.com/namespaces/example/3"/>
</a>
XML
<a xmlns:ns="http://www.twoshortplanks.com/namespaces/example/1" xmlns:ns2="http://www.twoshortplanks.com/namespaces/example/2" xmlns:ns3="http://www.twoshortplanks.com/namespaces/example/3">
  <ns:b>
     <ns2:c>
       <ns2:d/>
     </ns2:c>
  </ns:b>
  <ns3:e/>
</a>
XML

eval {
  process <<'XML'
<bar xmlns::foo="bad ns"/>
XML
};
like($@, qr/Specification violation: Can't have more than one colon in attribute name 'xmlns::foo'/, "bang - attr name 1/3");

eval {
  process <<'XML'
<bar xmlns:fo:o="bad ns"/>
XML
};
like($@, qr/Specification violation: Can't have more than one colon in attribute name 'xmlns:fo:o'/, "bang - attr name 2/3");

eval {
  process <<'XML'
<bar xmlns:foo:="bad ns"/>
XML
};
like($@, qr/Specification violation: Can't have more than one colon in attribute name 'xmlns:foo:'/, "bang - attr name 3/3");


eval {
  process <<'XML'
<bar xmlns:xmlns="something else"/>
XML
};
like($@, qr/Specification violation: Can't assign any namespace to prefix 'xmlns'/, "bang - xmlns prefix");

eval {
  process <<'XML'
<bar xmlns:xml="something else"/>
XML
};
like($@, qr/Specification violation: Can't assign 'something else' to prefix 'xml'/, "bang - xml prefix");

eval {
  process <<'XML'
<bar xmlns:something="http://www.w3.org/2000/xmlns/"/>
XML
};
like($@, qr{Specification violation: Can't assign 'http://www.w3.org/2000/xmlns/' to any prefix}, "bang - xmlns namespace");


eval {
  process <<'XML'
<bar xmlns:xml="http://www.w3.org/XML/1998/namespace"/>
XML
};
ok(!$@, "no bang - xml ns for xml prefix");

eval {
  process <<'XML'
<foo:bar />
XML
};
like($@, qr/Prefix 'foo' has no registered namespace/, "bang - not reg");
