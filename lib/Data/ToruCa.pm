package Data::ToruCa;

use strict;
use MIME::Base64;

our $VERSION = '0.01';

our $VERBOSE = 0;

sub new {
    my $class = shift;
    my $opt = shift;

    my $self = bless {}, $class;
    if (ref($opt) eq 'HASH') {
        foreach (keys %$opt) {
            $self->{$_} = $opt->{$_};
        }
    } elsif (ref($opt) eq '' && $opt) {
        $self->parse($opt);
    }

    return $self;
}

sub _warn {
    warn shift
	if ($VERBOSE);
}

sub ext {'trc'}
sub content_type {'application/x-toruca'}

sub _accessor {
    my $self  = shift;
    my $field = shift;
    my $size  = shift;
    my $data  = shift;
    return $self->{$field} unless $data;
    _warn "length of $field is too large($size bytes)."
        if length($data) > $size;
    $self->{$field} = $data;
}
sub version {shift->_accessor('version', 4, @_)}
sub type    {shift->_accessor('type', 8, @_)}
sub url     {shift->_accessor('url', 127, @_)}
sub data1   {shift->_accessor('data1', 20, @_)}
sub data2   {shift->_accessor('data2', 100, @_)}
sub data3   {shift->_accessor('data3', 20, @_)}
sub cat     {shift->_accessor('cat', 4, @_)}

sub parse {
    my $self = shift;
    my $trc = shift;

    unless ($trc =~ /^ToruCa\r\n/) {
        _warn 'toruca format error.';
        return 0;
    }

    foreach (split(/\r\n/, $trc)) {
        if (/^([^:]+): (.+)$/) {
            my ($field, $data) = (lc($1), $2);
            $data = decode_base64($data)
                if ($field =~ /^data/);
            $self->_accessor($field, 200, $data);
        }
    }
    return 1;
}

sub _build {
    my $self = shift;

    _warn 'length of (url & data1 & data2 & data3) is too large(173 bytes).'
        if length($self->url.$self->data1.$self->data2.$self->data3) > 173;

    _warn 'url schme error (http only).'
        unless $self->url =~ m|^http://|i;

    $self->version('1.0') unless $self->version;
    $self->type('SNIP') unless $self->type;
    $self->cat('0000') unless $self->cat =~ m|^[0-9a-fA-F]{4,4}$|;
    $self->cat('0000') unless $self->cat;
    $self->cat(uc($self->cat));
}

sub _build {
    my $self = shift;

    _warn 'length of (url & data1 & data2 & data3) is too large(173 bytes).'
        if length($self->url.$self->data1.$self->data2.$self->data3) > 173;

    _warn 'url schme error (http only).'
        unless $self->url =~ m|^http://|i;

    $self->version('1.0') unless $self->version;
    $self->type('SNIP') unless $self->type;
    $self->cat('0000') unless $self->cat =~ m|^[0-9a-fA-F]{4,4}$|;
    $self->cat('0000') unless $self->cat;
    $self->cat(uc($self->cat));
}

sub build {
    my $self = shift;

    $self->_build;

    return "ToruCa\r\n".
    'Version: '. $self->version. "\r\n".
    'Type: '. $self->type. "\r\n".
    "\r\n".
    'URL: '. $self->url. "\r\n".
    'Data1: '. $self->_base64($self->data1). "\r\n".
    'Data2: '. $self->_base64($self->data2). "\r\n".
    'Data3: '. $self->_base64($self->data3). "\r\n".
    'Cat: '. $self->cat. "\r\n".
    "\r\n";
}

sub html_build {
    my $self = shift;
    my $html = shift;


    my $toruca = $self->build;

    srand(time | $$);
    my $boundary;
    my $i = 0;
    while (1) {
	$i++;
	return if $i > 100;
        $boundary = sprintf("%010d", rand(1000000000));
        last unless $html =~ /$boundary/;
    }

    return $toruca
        . "MIME-Version: 1.0\r\n"
        . "Content-Type: multipart/mixed;boundary=\"$boundary\"\r\n"
        . "\r\n"
        . "--$boundary\r\n"
        . "Content-Type: text/html; charset=Shift_JIS\r\n"
        . "Content-Transfer-Encoding: 8bit\r\n"
        . "\r\n"
        . "$html\r\n"
        . "--$boundary--\r\n";
}

sub rw_build {
    my $self = shift;

    $self->_build;

    my $subprm = "\x01\x31\x30" .
        pack("v", length($self->url)) . $self->url .
        pack("v", length($self->data1)) . $self->data1 .
        pack("v", length($self->data2)) . $self->data2 .
        pack("v", length($self->data3)) . $self->data3;
    $self->cat =~ /^(..)(..)$/;
    my ($catb, $catl) = ($1, $2);
    eval "\$subprm .= \"\\x$catb\\x$catl\";";

    my $data = "\x01\x20" . pack("v", length($subprm)) . $subprm;

    my $sum = 0;
    foreach (split(//, $data)) {
        $sum += unpack("C", $_);
    }
    $data .= pack("n", 65536 - ($sum % 65536));

    return $data;
}

sub _base64 {
    my $self = shift;
    my $data = encode_base64(shift);
    $data =~ s/\s//g;
    return $data;
}

1;
__END__

=head1 NAME

Data::ToruCa - ToruCa of NTT DoCoMo for treated.

=head1 SYNOPSIS

  use Data::ToruCa;
  $Data::ToruCa::VERBOSE = 1;#Warning is output by the favorite.

  my $trc = Data::ToruCa->new($toruca_data);#making from ToruCa data.

  my $trc = Data::ToruCa->new({
      url => 'http://example.jp/toruca_detail.trc',
      data1 => 'title',
      data2 => 'description.',
      data3 => 'Tokyo',
      cat => '0001',
    });#making from HASH.

    $trc->data1('change title');
    print $trc->url;

    print $trc->build;

    $trc->type('CARD');
    $trc->html_build('<a href='http://example.jp/'>top page</a>');

=head1 DESCRIPTION

ToruCa that the cellular phone of NTT DoCoMo in Japan uses is treated.

=head1 Methods

=over 4

=item new($toruca_object)

making from ToruCa data.

=item new(%toruca_data)

making from HASH.

=item ext

get of ext type of ToruCa.

=item content_type

get of Content-Type of ToruCa.

=item version([$set_data])

getter/setter of ToruCa Version.

=item type([$set_data])

getter/setter of ToruCa Type.

=item url([$set_data])

getter/setter of ToruCa URL.

=item data1([$set_data])

getter/setter of ToruCa Data1.

=item data2([$set_data])

getter/setter of ToruCa Data2.

=item data3([$set_data])

getter/setter of ToruCa Data3.

=item cat([$set_data])

getter/setter of ToruCa category.

=item parse($toruca_object)

The ToruCa data is anakyzed.

=item build

The ToruCa data is made.

=item html_build

The detailed data of ToruCa is made.

=item rw_build($html)

The ToruCa data for Felica is made.

Onlu one html file can be appended.

=back


=head1 SEE ALSO

japanese site.

http://www.nttdocomo.co.jp/p_s/imode/make/toruca/index.html

=head1 AUTHOR

Kazuhiro, Osawa<lt>ko@yappo.ne.jpE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 by Kazuhiro, Osawa

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.5 or,
at your option, any later version of Perl 5 you may have available.


=cut
