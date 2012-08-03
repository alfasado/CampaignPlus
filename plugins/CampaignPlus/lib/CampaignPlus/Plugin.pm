package CampaignPlus::Plugin;

use strict;
use lib qw( addons/Commercial.pack/lib addons/PowerCMS.pack/lib );
use PowerCMS::Util qw( current_ts utf8_on utf8_off csv_new );

sub list_actions {
    my $actions = {
        export_campaign_info => {
            # button    => 1,
            label       => 'Export Campaign',
            mode        => 'export_campaign_info',
            # class     => 'icon-action',
            # return_args => 1,
            order       => 2000,
        },
    };
    return $actions;
}

sub export_campaign_info {
    my $app = shift;
    require Campaign::Plugin;
    my @ids = $app->param( 'id' );
    my $column_names = $app->model( 'campaign' )->column_names;
    my $publishcharset = $app->config( 'PublishCharset' );
    my $csv = csv_new() || return $app->trans_error( 'Neither Text::CSV_XS nor Text::CSV is available.' );
    $app->{ no_print_body } = 1;
    my $ts = current_ts();
    $app->set_header( 'Content-Disposition' => "attachment; filename=csv_$ts.csv" );
    $app->send_http_header( 'text/csv' );
    if ( $csv->combine( @$column_names ) ) {
        my $string = $csv->string;
        if ( $publishcharset ne 'Shift_JIS' ) {
            $string = utf8_off( $string );
            $string = MT::I18N::encode_text( $string, 'utf8', 'cp932' );
        }
        print $string, "\n";
    }
    my @campaigns = $app->model( 'campaign' )->load( { id => \@ids } );
    for my $campaign ( @campaigns ) {
    # for my $id ( @ids ) {
        my @values;
        # my $campaign = $app->model( 'campaign' )->load( $id );
        # return $app->errtrans( 'Invalid request.' ) unless $campaign;
        if (! Campaign::Plugin::_campaign_permission( $campaign->blog ) ) {
            return $app->trans_error( 'Permission denied.' );
        }
        for my $column ( @$column_names ) {
            my $value = $campaign->$column;
            if ( $column =~ /_on$/ ) {
                if ( $value ) {
                    $value = "\t" . $value;
                }
            }
            push ( @values, $value );
        }
        if ( $csv->combine( @values ) ) {
            my $string = $csv->string;
            if ( $publishcharset ne 'Shift_JIS' ) {
                $string = utf8_off( $string );
                $string = MT::I18N::encode_text( $string, 'utf8', 'cp932' );
            }
            print $string, "\n";
        }
    }
}

sub cms_post_save_campaign {
    my ( $cb, $app, $obj, $original ) = @_;
    if (! $app->config( 'RebuildIndexAtSaveCampaign' ) ) {
        return 1;
    }
    if ( ( $obj->status != 2 ) and ( $original && ( $obj->status == $original->status ) ) ) {
        return 1;
    }
    require MT::WeblogPublisher;
    my $pub = MT::WeblogPublisher->new;
    $pub->rebuild_indexes( BlogID => $obj->blog_id, Force => 1, );
    return 1;
}

sub cms_post_save_campaigngroup {
    my ( $cb, $app, $obj, $original ) = @_;
    if (! $app->config( 'RebuildIndexAtSaveCampaignGroup' ) ) {
        return 1;
    }
    require MT::WeblogPublisher;
    my $pub = MT::WeblogPublisher->new;
    $pub->rebuild_indexes( BlogID => $obj->blog_id, Force => 1, );
    return 1;
}

sub edit_campaign_param {
    my ( $cb, $app, $param, $tmpl ) = @_;
    if ( $app->config( 'RebuildIndexAtSaveCampaign' ) ) {
        $param->{ saved } = '';
    }
}

sub edit_campaigngroup_param {
    my ( $cb, $app, $param, $tmpl ) = @_;
    if ( $app->config( 'RebuildIndexAtSaveCampaignGroup' ) ) {
        $param->{ saved } = '';
    }
}

sub _hdlr_flagged_campaigns {
    my ( $ctx, $args, $cond ) = @_;
    my $tokens = $ctx->stash( 'tokens' );
    my $builder = $ctx->stash( 'builder' );
    my $field = $args->{ field };
    require Campaign::Campaign;
    my @campaigns = Campaign::Campaign->search_by_meta( 'field.' . $field, 1 );
    my $res = '';
    for my $campaign ( @campaigns ) {
        local $ctx->{ __stash }{ campaign } = $campaign;
        my ( $url, $w, $h );
        if ( $campaign->image_id ) {
            ( $url, $w, $h ) = $campaign->banner;
        } else {
            $w = $campaign->banner_width;
            $h = $campaign->banner_height;
        }
        local $ctx->{ __stash }{ campaign_banner_url }    = $url;
        local $ctx->{ __stash }{ campaign_banner_width }  = $w;
        local $ctx->{ __stash }{ campaign_banner_height } = $h;
        local $ctx->{ __stash }{ campaign_asset_image }   = $campaign->image if $campaign->image_id;
        my $out = $builder->build( $ctx, $tokens, $cond );
        $res .= $out;
    }
    return $res;
}

sub _hdlr_flagged_campaign_title {
    my ( $ctx, $args ) = @_;
    my $campaign = $ctx->stash( 'campaign' );
    return $campaign->title if $campaign;
    return '';
}

sub _hdlr_if_campaign_flagged {
    my ( $ctx, $args, $cond ) = @_;
    my $campaign = $ctx->stash( 'campaign' );
    my $field = $args->{ field };
    my $column = 'field.' . $field;
    if ( $campaign->$column ) {
        return 1;
    }
    return 0;
}

sub example_method {
    # my $app = shift;
    # require MT::Entry;
    #     my @entries = MT::Entry->load( { blog_id => 2, status => 2 },
    #                                    { limit => 2, offset => 2,
    #                                      sort_by => 'authored_on',
    #                                      direction => 'descend' } );
    #     my $res = '<pre>';
    #     for my $entry ( @entries ) {
    #         # $entry->title( 'Foo' );
    #         $res .= $entry->title;
    #         # $entry->save;
    #         $res .= "\n";
    #     }
    #     return $res;
    # my $entry = MT::Entry->new;
    # $entry->title( 'This is it!' );
    # $entry->status( 1 );
    # $entry->author_id( 1 );
    # $entry->blog_id( 2 );
    
    # $entry->set_values( { blog_id => 2, title => 'This is it!', status => 1, author_id => 1 } );
    # $entry = MT->model( 'page' )->get_by_key( { blog_id => 2, title => 'This is it!', status => 1, author_id => 1 } );
    # $entry->save;
    # return $entry->title;
}

1;