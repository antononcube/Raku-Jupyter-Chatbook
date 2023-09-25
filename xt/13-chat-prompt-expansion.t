#!/usr/bin/env perl6
use lib 'lib';
use Test;
use Log::Async;
use Jupyter::Kernel::Magics;
use LLM::Prompts;

logger.add-tap( -> $msg { diag $msg<msg> } );

plan *;

my $m = Jupyter::Kernel::Magics.new;
class MockResult {
    has $.output;
    has $.output-mime-type;
    has $.stdout;
    has $.stdout-mime-type;
    has $.stderr;
    has $.exception;
    has $.incomplete;
}


{
    my $code = q:to/DONE/;
    %% chat > html
    @CodeWriterX|HTML Random table with with 5 rows and 4 columns with values that are both words and numbers.
    DONE

    ok my $magic = $m.find-magic($code), 'preprocess recognized %% chat';
    is $code.starts-with('@CodeWriterX'), True, 'content of the chat cell';
    my $r = $magic.preprocess($code);
    note $r.output;

    # Dear <name>....
    is $r.output.contains('<table>', :i),
            True,
            'response contains "<table>"';

    is $r.output-mime-type, 'text/html', 'chat magic set the mime type';
}


{
    my $code = q:to/DONE/;
    %% chat > markdown, conf=ChatPaLM
    @Yoda Some people live for tomorrow!
    DONE

    ok my $magic = $m.find-magic($code), 'preprocess recognized %% chat';
    is $code.starts-with('@Yoda'), True, 'content of the chat cell';
    my $r = $magic.preprocess($code);
    note $r.output;

    # Dear <name>....
    is $r.output.contains('tomorrow', :i) || $r.output.contains('future', :i),
            True,
            'response contains "tomorrow" or "future';

    is $r.output-mime-type, 'text/markdown', 'chat magic set the mime type';
}

{
    my $code = q:to/DONE/;
    %% chat, conf=ChatPaLM
    !Translated|German> To live for tomorrow?
    DONE

    ok my $magic = $m.find-magic($code), 'preprocess recognized %% chat';
    is $code.starts-with('@Yoda'), True, 'content of the chat cell';
    my $r = $magic.preprocess($code);
    note $r.output;

    # Dear <name>....
    is $r.output.contains('morgen', :i) || $r.output.contains('Zukunft', :i),
            True,
            'response contains "tomorrow" or "future';

    is $r.output-mime-type, 'text/plain', 'chat magic set the mime type';
}

done-testing;