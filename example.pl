
sub UnGrib_CSF {
    my %filename_map = (       # prefix -> incoming files mask mapping
        'PLEVS' => 'flxf*grb2',
        'SFLUX' => 'pgbf*grb2',
    );

    my %vtable_map = (          # prefix -> vtable mapping
        'PLEVS' => 'Vtable.CFSR_sfc_flxf06',
        'SFLUX' => 'Vtable.CFSR_press_pgbh06',
    );

    for my $prefix ( qw(PLEVS SFLUX) ) {
        Running_link_grid_csh($filename_map{$prefix});

        replace_field_name( qq/^.*prefix/ => qq/!prefix/);      # disabling all prefixes
        replace_field_name( qq/^.*prefix.*$prefix.*/ => qq/ prefix = '$prefix'/);   # enabling current prefix
        
        my $exit_code = system("ln -sf $wps/ungrib/Variable_Tables/$vtable_map{$prefix} $wps/Vtable");
        if ($exit_code) { die "Error creating soft link: ln -sf $wps/ungrib/Variable_Tables/$vtable_map{$prefix} $wps/Vtable"; }
        
        Running_UnGrib();
        
        my @gribfiles = glob "$wps/GRIBFILE.A*";
        if ( @gribfiles ) {
            print "Removing files from $wps: " . ( join ',', @gribfiles ) . "\n";
            unlink @gribfiles;	   
        }
    }
    replace_field_name( qq/^.*prefix/ => qq/!prefix/);      # disabling all prefixes
}

sub replace_field_name {
    my %substitutes = @_;

    my $tmp_file = "/tmp/$Script";
    open TMP, ">$tmp_file";
    open INPUT, "<$name_list";

    while (my $line = <INPUT>) {
        $line =~ s/$_/$substitutes{$_}/ for keys %substitutes;
        print TMP $line;
    }   

    close TMP;
    close INPUT;
    
    copy ($tmp_file, $name_list) ; 

    unlink $tmp_file;
}

sub mail_gmail {
    $subject = shift;
    $body = shift;

    my %recipients = (  # add repicients below
        '_____@gmail.com'      => 'Gilad',
    );

    for my $to_mail_id ( keys %recipients ) {
        my $greeting = "Hello $recipients{$to_mail_id}\n\n";

        my $email = Email::Simple->create(
            header => [
                From    => $from_mail_id,
                To      => $to_mail_id,
                Subject => $subject,
            ],
            body => $greeting . $body,
        );

        my $sender = Email::Send->new(
            { mailer      => 'Gmail',
              mailer_args => [
                  username => $from_mail_id,
                  password => $from_pass,
              ]
            }
        );
        eval { $sender->send($email) };
        die "Error sending email: $@" if $@;
    }
}

sub send_email_notification {
    my $type    = shift;    # keys of %templates
    my $time    = shift;
    my $error   = shift;    # if type = 'error'

    my $hostname    = hostname;
    my $date        = strftime '%Y-%m-%d', gmtime();
    
    my %templates = (
        'start' => {
            subject => "Start of daily forecast ($date)",
            body    =>
                "Start of Simulation:"          . "\n" .
                "-----------------------"       . "\n" .
                "  Started at: $time"           . "\n" .
                "  GFS cycle:  00"              . "\n" .
                "  Run on server:  $hostname"   . "\n" .
                "--",
        },

        'finish' => {
            subject  => "Success of daily forecast ($date)",
            body     =>
                "End of Simulation:"            . "\n" .
                "-----------------------"       . "\n" .
                "  Finished at: $time"          . "\n" .
                "  GFS cycle:  00"              . "\n" .
                "  Run on server:  $hostname"   . "\n" .
                "--",
        }, 
        'error' => {
            subject  => "Failure of daily forecast ($date)",
            body     =>
                "Error in Simulation:"          . "\n" .
                "-----------------------"       . "\n" .
                "  Stopped at: $time"           . "\n" .
                "  Error message: $error"       . "\n" .
                "  GFS cycle:  00"              . "\n" .
                "  Run on server:  $hostname"   . "\n" .
                "--",
        },
        '_undef' => {
            subject => "Email from $host",
            body    => "send_email_notification sub was called in wrong format\non " . localtime
                        . "\nwith params " . (join ', ', @_),
        },
    );
    
    my $template = $templates{$type} || $templates{_undef};
    mail_gmail( $template->{subject}, $template->{body} );
}
