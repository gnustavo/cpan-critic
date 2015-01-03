use v5.20;
use feature qw(postderef);
no warnings qw();

package CPAN::Critic;
use strict;

use warnings;
no warnings;

use subs qw();
use vars qw($VERSION);

use Cwd;
use ReturnValue;
use File::Find;
use File::Spec::Functions qw(catfile splitdir);

$VERSION = '0.10_01';

=encoding utf8

=head1 NAME

CPAN::Critic - Critique a CPAN distribution

=head1 SYNOPSIS

	use CPAN::Critic;

=head1 DESCRIPTION

=over 4

=item new

=cut

sub new {
	my( $class ) = shift;
	my $self = bless {}, $class;
	
	$self->_init( @_ );
	
	$self;
	}
	
sub _init {
	my( $self, %args ) = @_;
	
	# $args{config} //= $self->_default_config;
	
	my $result = $self->_load_default_policies;
	if( $result->is_error ) {
	
	
		}
		
	my %namespaces = $result->value->%*;
	my @namespaces = keys %namespaces;
	
	$self->{config}{policies} = \@namespaces;
	# $self->config( $self->_load_config );
	
	# remove policies by config
	
	$self;
	}

sub _default_config {
	'cpan-critic.ini'
	}

sub _load_default_policies {
	my( $self ) = @_;

	my %Results;
	my $errors = 0;

	POLICY: foreach my $namespace ( $self->_find_policies ) {
		unless( $namespace =~ m/\A [A-Z0-9_]+ (::[A-Z0-9_]+)+ \z/xi ) {
			$Results{_errors}{$namespace} = "Bad namespace [$namespace]";
			$Results{$namespace} = 0;
			next POLICY;
			}
			
		unless( eval "require $namespace; 1" ) {
			say "Error with $namespace: $@";
			$Results{_errors}{$namespace} = "Problem loading $namespace: $@";
			$Results{$namespace} = 0;
			$errors++;
			next POLICY;
			}
			
		$Results{$namespace}++;
		}
	
	my $method = $errors ? 'error' : 'success';
		
	ReturnValue->$method(
		value => \%Results,
		);
	}

sub _find_policies {
	my( $self ) = @_;

	my @dirs = map { 
		File::Spec->catfile( $_, qw(CPAN Critic Policy) )
		} @INC;
	
	my @namespaces;
	foreach my $dir ( @dirs ) {
		my @files;	
		my $wanted = sub { 
			push @files, 
				File::Spec::Functions::canonpath( $File::Find::name ) if m/\.pm\z/ 
				};
		find( $wanted, $dir );
		
		push @namespaces, map {
			my $rel = File::Spec->abs2rel( $_, $dir );
			$rel =~ s/\.pm\z//;
			my @parts = splitdir( $rel );
			join '::', qw(CPAN Critic Policy), @parts;
			} @files;
		#say join "\n\t", "Found", @files;
		}
				
	
	@namespaces;
	}

=item config( CONFIG )

=cut

sub config {
	my( $self ) = shift;
	
	$self->{config} = $_[0] if @_;
	
	$self->{config}
	}

=item critique( DIRECTORY )

Apply all the policies to the given directory.

=cut

sub critique {
	my( $self, $dir ) = @_;

	defined $dir or return ReturnValue->error(
		value       => undef,
		description => "No directory argument: $!",
		tag         => 'system',
		);
			
	my $starting_dir = cwd();
	chdir $dir or return ReturnValue->error(
		value       => undef,
		description => "Could not change to directory [$dir]: $!",
		tag         => 'system',
		);
		
	my @results;
	foreach my $policy ( $self->policies ) {
		say "Applying $policy";
		my $result = $self->apply( $policy );
		
		push @results, $result;
		}

	chdir $starting_dir or return ReturnValue->error(
		value       => undef,
		description => "Could not change back to original directory [$dir]: $!",
		tag         => 'system',
		);

	say Dumper( \@results ); use Data::Dumper;
		
	return ReturnValue->success(
		value => \@results,
		);
	}

=item apply( POLICY )

=cut

sub apply {
	my( $self, $policy ) = @_;
	
	$policy->run();
	}

=item policies

Return a list of policy objects

=cut

sub policies {
	my( $self ) = @_;
	
	wantarray 
		? 
		$self->config->{policies}->@* 
			: 
		[ $self->config->{policies}->@* ]
		;
	}

=back

=head1 TO DO


=head1 SEE ALSO


=head1 SOURCE AVAILABILITY

This source is in Github:

	http://github.com/briandfoy/cpan-critic/

=head1 AUTHOR

brian d foy, C<< <bdfoy@cpan.org> >>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2015, brian d foy, All Rights Reserved.

You may redistribute this under the same terms as Perl itself.

=cut

1;
