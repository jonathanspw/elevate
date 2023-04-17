package Elevate::Blockers::Distros;

=encoding utf-8

=head1 NAME

Elevate::Blockers::Distros

Blocker to check compatibility with current distribution.

=cut

use cPstrict;

use Cpanel::OS ();

use constant MINIMUM_CENTOS_7_SUPPORTED => 9;

use parent qw{Elevate::Blockers::Base};

use Log::Log4perl qw(:easy);

sub check ($self) {

    my @checks = qw{
      _blocker_is_non_centos7
      _blocker_is_old_centos7
      _blocker_is_experimental_os
    };

    foreach my $name (@checks) {
        my $blocker = $self->can($name)->($self);
        return $blocker if $blocker;
    }

    return 0;
}

sub _blocker_is_non_centos7 ($self) {
    unless ( Cpanel::OS::major() == 7 && Cpanel::OS::distro() eq 'centos' ) {
        my $pretty_distro_name = $self->upgrade_to_pretty_name();
        return $self->has_blocker(qq[This script is only designed to upgrade CentOS 7 to $pretty_distro_name.]);
    }

    return 0;
}

sub _blocker_is_old_centos7 ($self) {
    if ( Cpanel::OS::minor() < MINIMUM_CENTOS_7_SUPPORTED ) {
        my $pretty_distro_name = $self->upgrade_to_pretty_name();
        return $self->has_blocker(
            sprintf(
                'You need to run CentOS 7.%s and later to upgrade %s. You are currently using %s',    #
                MINIMUM_CENTOS_7_SUPPORTED, $pretty_distro_name, Cpanel::OS::display_name()           #
            )
        );
    }

    return 0;
}

sub _blocker_is_experimental_os ($self) {
    if ( -e '/var/cpanel/caches/Cpanel-OS.custom' ) {
        return $self->has_blocker('Experimental OS detected. This script only supports CentOS 7 upgrades');
    }

    return 0;
}

# We are OK if can_be_elevated or if
sub bail_out_on_inappropriate_distro () {

    if ( !( eval { Cpanel::OS::can_be_elevated() } // ( Cpanel::OS::distro() eq 'centos' && Cpanel::OS::major() == 7 ) ) ) {
        FATAL(qq[This script is designed to only run on CentOS 7 servers.\n]);
        exit 1;
    }

    return;
}

1;
