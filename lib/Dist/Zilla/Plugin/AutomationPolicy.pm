package Dist::Zilla::Plugin::AutomationPolicy;

use v5.24;

# ABSTRACT: add an automation policy to a distribution

use Moose;
with qw( Dist::Zilla::Role::FileGatherer Dist::Zilla::Role::PrereqSource Dist::Zilla::Role::FilePruner );

use Dist::AutomationPolicy;
use Dist::Zilla::File::InMemory;
use Dist::Zilla::Pragmas;
use MooseX::Types::Moose qw( HashRef );
use MooseX::Types::Perl  qw( StrictVersionStr );

use namespace::autoclean;

use experimental qw( postderef signatures );

our $VERSION = 'v0.0.2';

has version => (
    is      => 'ro',
    isa     => StrictVersionStr,
    default => 'v0.2.0',
);

has _policy_args => (
    is      => 'ro',
    isa     => HashRef,
    default => sub { {} },
);

has _policy => (
    is         => 'ro',
    lazy_build => 1,
    builder    => '_build_policy',
    handles    => [qw/ filename to_json /],
);

sub _build_policy ($self) {
    my $zilla = $self->zilla;
    my %args = $self->_policy_args->%*;
    $args{distribution} ||= join( "-", $zilla->name, $zilla->version );
    return Dist::AutomationPolicy->new(%args);
}

=for Pod::Coverage mvp_multivalue_args

=cut

sub mvp_multivalue_args { qw( models ) }

around plugin_from_config => sub( $orig, $class, $name, $args, $section ) {
    my %module_args;

    for my $key ( keys $args->%* ) {
        if ( $key =~ s/^-// ) {
            die "$key cannot be set" if $key eq "_policy_args";
            $module_args{$key} = $args->{"-$key"};
        }
        else {
            $module_args{_policy_args}{$key} = $args->{$key};
        }
    }

    return $class->$orig( $name, \%module_args, $section );
};

sub gather_files($self) {

    $self->add_file(
        Dist::Zilla::File::InMemory->new(
            name            => $self->filename,
            encoded_content => $self->to_json,
        )
    );

    return;
}

sub register_prereqs($self) {
    $self->zilla->register_prereqs( { phase => 'develop' }, "Dist::AutomationPolicy" => $self->version );
    return;
}

sub prune_files($self) {
    my @files    = @{ $self->zilla->files };
    my $filename = $self->filename;
    for my $file (@files) {
        $self->zilla->prune_file($file) if $file->name eq $filename && $file->added_by !~ __PACKAGE__;
    }
}

__PACKAGE__->meta->make_immutable;
