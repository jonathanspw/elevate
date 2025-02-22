#!/usr/local/cpanel/3rdparty/bin/perl

package test::cpev::blockers;

use FindBin;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;

use Test::MockFile 0.032;
use Test::MockModule qw/strict/;

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

use cPstrict;

require $FindBin::Bin . '/../elevate-cpanel';

my $blockers = cpev->new->blockers;
my $ea4      = $blockers->_get_blocker_for('EA4');

my $mock_ea4 = Test::MockModule->new('Elevate::Blockers::EA4');

my $mock_compoment_ea4 = Test::MockModule->new('Elevate::Components::EA4');
my $mock_cpev          = Test::MockModule->new('cpev');

{
    my $mock_isea4 = Test::MockFile->file( '/etc/cpanel/ea4/is_ea4' => 1 );
    my $type       = '';

    $mock_compoment_ea4->redefine( backup => sub { return; } );
    my $mock_cpev = Test::MockModule->new('cpev');
    $mock_cpev->redefine(
        _read_stage_file => sub {
            return {
                ea4 => {
                    dropped_pkgs => {
                        'ea4-bad-pkg' => $type,
                    },
                },
            };
        }
    );

    # only testing the blocking case

    like(
        $ea4->_blocker_ea4_profile(),
        {
            id  => q[Elevate::Blockers::EA4::_blocker_ea4_profile],
            msg => <<~'EOS',
        One or more EasyApache 4 package(s) are not compatible with AlmaLinux 8.
        Please remove these packages before continuing the update.
        - ea4-bad-pkg
        EOS

        },
        'blocks when EA4 has an incompatible package'
    );

    $mock_cpev->unmock_all;
}

{
    $mock_compoment_ea4->redefine( backup => sub { return; } );

    my $ea_info_check = sub {
        message_seen( 'INFO' => "Checking EasyApache profile compatibility with AlmaLinux 8." );
    };

    ok !$ea4->_blocker_ea4_profile(), "no ea4 blockers without an ea4 profile to backup";
    $ea_info_check->();

    my $stage_file = Test::MockFile->file( cpev::ELEVATE_STAGE_FILE() );

    my $stage_ea4 = {
        profile => '/some/file.not.used.there',
    };

    $mock_cpev->redefine(
        read_stage_file => sub {
            return { ea4 => $stage_ea4 };
        }
    );

    clear_messages_seen();

    ok( !$ea4->_blocker_ea4_profile(), "no ea4 blockers: profile without any dropped_pkgs" );

    $ea_info_check->();

    $stage_ea4->{'dropped_pkgs'} = {
        "ea-bar" => "exp",
        "ea-baz" => "exp",
    };
    ok( !$ea4->_blocker_ea4_profile(), "no ea4 blockers: profile with dropped_pkgs: exp only" );
    $ea_info_check->();

    $stage_ea4->{'dropped_pkgs'} = {
        "pkg1"   => "reg",
        "ea-baz" => "exp",
        "pkg3"   => "reg",
        "pkg4"   => "whatever",
    };

    ok my $blocker = $ea4->_blocker_ea4_profile(), "_blocker_ea4_profile ";
    $ea_info_check->();

    message_seen( 'WARN' => qr[Elevation Blocker detected] );

    like $blocker, object {
        prop blessed => 'cpev::Blocker';

        field id => q[Elevate::Blockers::EA4::_blocker_ea4_profile];
        field msg => 'One or more EasyApache 4 package(s) are not compatible with AlmaLinux 8.
Please remove these packages before continuing the update.
- pkg1
- pkg3
- pkg4
';

        end();
    }, "blocker with expected error" or diag explain $blocker;
}

done_testing();
