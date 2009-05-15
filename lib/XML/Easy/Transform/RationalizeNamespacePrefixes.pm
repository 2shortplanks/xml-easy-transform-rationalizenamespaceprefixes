package XML::Easy::Transform::RationalizeNamespacePrefixes;
use base qw(Exporter);

our @EXPORT;

use strict;
use warnings;

=head1 SYNOPSIS

  use XML::Easy::Transform::RationalizeNamespacePrefixes qw(
     rationalize_namespace_prefixes
  );
  
  my $doc = rationalize_namespace_prefixes(
     xml10_read_document($text)
  );

=head1 DESCRIPTION

This code creates a new tree of XML::Easy::Element nodes by examining
an existing XML::Easy::Element tree and producing a new tree that is
schemantically identical under the XML Namespaces 1.0 specification
but with all namespace declartions moved to the top node of the tree
(this may involve renaming several elements in the tree to have different
prefixes.)

For example:

  sub process($) {
    return xml10_write_document(
      rationalize_namespace_prefixes(
        xml10_read_document( $_[0] )
      ),"UTF-8"
    );
  }
  
  print process <<'XML';
  <foo>
    <ex1:bar xmlns:ex1="http://www.twoshortplanks.com/namespace/example/1"/>
  </foo>
  XML

Moves the namespace up and prints:

  <foo xmlns:ex1="http://www.twoshortplanks.com/namespace/example/1">
    <ex1:bar/>
  </foo>

The routine will also create prefixes as needed:

  print process <<'XML';
  <foo>
    <bar xmlns="http://www.twoshortplanks.com/namespace/example/1"/>
  </foo>
  XML

Prints

  <foo xmlns:default2="http://www.twoshortplanks.com/namespace/example/1">
    <default2:bar/> 
  </foo>

It even copes with conflicting prefixes:

  print process <<'XML';
  <muppet:kermit xmlns:muppet="http://www.twoshortplanks.com/namespace/example/muppetshow">
    <muppet:kermit xmlns:muppet="http://www.twoshortplanks.com/namespace/example/seasmestreet" />
  </muppet:kermit>
  XML

Prints

  <muppet:kermit xmlns:muppet="http://www.twoshortplanks.com/namespace/example/muppetshow" xmlns:muppet2="http://www.twoshortplanks.com/namespace/example/seasmestreet">
    <muppet2:kermit/>
  </muppet:kermit>

This module also removes all unnecessary prefixes on attributes:

  <wobble xmlns:ex1="http://www.twoshortplanks.com/namespace/example/1">
    <ex1:wibble ex1:jelly="in my tummy"/>
  </wobble>

Will be transformed into

  <wobble xmlns:ex1="http://www.twoshortplanks.com/namespace/example/1">
    <ex1:wibble jelly="in my tummy"/>
  </wobble>

=cut

{
  our $prefix_generator;


  my %default_known_prefixes = (
    # include these as we're not meant to freak out if these namespaces are used
    xml => "http://www.w3.org/XML/1998/namespace",
    xmlns => "http://www.w3.org/2000/xmlns/",
    
    # by default the empty string is bound to ""
    "" => "",
  );

  # this holds the namespaces that we've assigned.
  my %assigned_prefixes;
  my %assigned_ns;

  sub rationalize_namespace_prefixes ($;&) {
    my $source_element = shift;
    local $prefix_generator = shift || \&_prefix_generator;

    # create the modified tree and populate our two local hashes with
    # the namespaces we should have

    %assigned_prefixes = ();
    %assigned_ns = ();
    my $dest_element = _rnp($source_element, \%default_known_prefixes);
    
    # we now have a tree with *no* namespaces.  Replace the top of that
    # tree with a new element that is the same as the top element of the tree but
    # with the needed namespace declarations
    
    my $attr = +{ %{ $dest_element->attributes }, map {
      ($_ ne "") ? ("xmlns:$_" => $assigned_prefixes{$_}) :
        ($assigned_prefixes{""} ne "") ? ( xmlns => $assigned_prefixes{""} ) : ()
    } keys %assigned_prefixes };
    
    return XML::Easy::Element->new($dest_element->type_name, $attr, $dest_element->content_object);
  }
  push @EXPORT, "rationalize_namespace_prefixes";

  sub _rnp {
    my $element = shift;

    # what namespaces are in scope at the momement
    my $known_prefixes = shift;

    # boolean that indicates if known_* is our copy or the
    # version passed in (has it been copy-on-write-ed)
    my $cowed = 0;
    
    # change the name of the element
    my $attr = $element->attributes;
    foreach (sort keys %{ $attr }) {
      next unless /\Axmlns(?::(.*))?\z/;
      my $prefix = defined $1 ? $1 : "";
      my $ns     = $attr->{$_};

      # check for things assigning namespaces to reserved places
      die "Specification violation: Can't assign '$ns' to prefix 'xml'"
        if $prefix eq "xml" && $ns ne 'http://www.w3.org/XML/1998/namespace';
      die "Specification violation: Can't assign 'http://www.w3.org/2000/xmlns/' to any prefix"
        if $ns eq 'http://www.w3.org/2000/xmlns/';

      # check we're not assigning things to the xmlns prefix
      die "Specification violation: Can't assign any namespace to prefix 'xmlns'"
        if $prefix eq 'xmlns';

      # copy the hash if we haven't done so already
      unless ($cowed) {
        $known_prefixes = +{ %{ $known_prefixes } };
        $cowed = 1;
      }

      # record that this prefix maps to this namespace;
      $known_prefixes->{ $prefix } = $ns;

      unless ($assigned_ns{ $ns }) {
        # find an unused unique prefix in the destination.
        while (exists $assigned_prefixes{ $prefix }) {
          $prefix = $prefix_generator->($prefix);
        }

        # remember that we're mapping that way
        $assigned_prefixes{ $prefix } = $ns;
        $assigned_ns{ $ns } = $prefix;
      }

    }

    # munge the prefix on the main element
    $element->type_name =~ /\A([^:]+)(?::(.*))?\z/
      or die "Invalid element name '".$element->type_name."'";
    my $prefix     = defined ($2) ? $1 : "";
    my $local_name = defined ($2) ? $2 : $1;

    # map the prefix in the source document to a namespace,
    # then look up the corrisponding prefix in the destination document
    my $element_ns;
    my $new_element_prefix;
    if ($prefix eq "" && !exists($assigned_prefixes{""})) {
      # someone just used the default (empty) prefix for the first time without having
      # declared an explict namespace.  Remember that the empty namespace exists.
      $element_ns = $assigned_prefixes{""} = "";
      $new_element_prefix = $assigned_ns{""} = "";
    } else {
      $element_ns = $known_prefixes->{ $prefix };
      unless (defined $element_ns) { die "Prefix '$prefix' has no registered namespace" }
      $new_element_prefix = $assigned_ns{ $element_ns };
    }
    my $new_element_name = (length $new_element_prefix) ? "$new_element_prefix:$local_name" : $local_name;

    # munge the prefix on the attribute elements
    my $new_attr = {};
    foreach (keys %{ $attr }) {
      /\A([^:]+)(?::(.*))?\z/
        or die "Invalid attribute name '$_'";
      my $prefix     = defined ($2) ? $1 : "";
      my $local_name = defined ($2) ? $2 : $1;
      
      # skip the namespaces
      next if $prefix eq "" && $local_name eq "xmlns";
      next if $prefix eq "xmlns";
      
      # map the prefix in the source document to a namespace,
      # then look up the corrisponding prefix in the destination document
      my $ns = $prefix eq "" ? $element_ns : $known_prefixes->{ $prefix };
      unless (defined $ns) { die "Prefix '$prefix' has no registered namespace" }
      my $new_prefix = $assigned_ns{ $ns };
      
      my $final_name = ($new_prefix ne $new_element_prefix) ? "$new_prefix:$local_name" : $local_name;
      $new_attr->{ $final_name } = $attr->{ $_ };
      
    }
    
    my @content = @{ $element->content };
    my @new_content;
    while (@content) {
      push @new_content, shift @content;
      if (@content) {
        push @new_content, _rnp((shift @content), $known_prefixes);
      }
    }
    
    return XML::Easy::Element->new( $new_element_name, $new_attr, \@new_content );
  }
}

sub _prefix_generator {
  my $prefix = shift;

  # "" => default2 (the 2 is concatinated later)
  $prefix = "default" if $prefix eq "";

  # turn foo into foo2 and foo2 into foo3, etc.
  $prefix .= "2" unless $prefix =~ s/(\d+)$/ $1 + 1 /e;

  return $prefix;
}

