#!/usr/bin/env perl6
use lib 'lib';
use Test;
use Log::Async;
use Jupyter::Chatbook::Magics;

logger.add-tap( -> $msg { diag $msg<msg> } );

plan *;

my $m = Jupyter::Chatbook::Magics.new;
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
    %% chat, conf=ChatPaLM, prompt = ⎡Pretend you are a friendly snowman. Stay in character for every response you give me. Keep your responses short. Feel free to ask me questions, too.⎦
    Hi!
    DONE

    ok my $magic = $m.find-magic($code), 'preprocess recognized %% chat';
    is $code, "Hi!\n", 'content of the chat cell';
    my $r = $magic.preprocess($code);
    #note $r.output;
    # Hi there! I'm a friendly snowman. What's your name?
    is $r.output-mime-type, 'text/plain', 'chat magic set the mime type';
}

{
    my $code = q:to/DONE/;
    %% chat
    Who are you!
    DONE

    ok my $magic = $m.find-magic($code), 'preprocess recognized %% chat';
    is $code, "Who are you!\n", 'content of the chat cell';
    my $r = $magic.preprocess($code);
    #note $r.output;
    # Hi there! I'm a friendly snowman. What's your name?
    is $r.output.contains('snowman'):i, True, 'response contains "snowman"';
    is $r.output-mime-type, 'text/plain', 'chat magic set the mime type';
}

{
    my $code = q:to/DONE/;
    %% chat-re8989, conf=ChatPaLM, prompt = ⎡Given a topic, write emails in a concise, professional manner⎦
    Request vacation time next week.
    DONE

    ok my $magic = $m.find-magic($code), 'preprocess recognized %% chat';
    is $code, "Request vacation time next week.\n", 'content of the chat cell';
    my $r = $magic.preprocess($code);
    #note $r.output;
    # Dear <name>....
    is $r.output.contains('vacation'):i, True, 'response contains "vacation"';
    is $r.output-mime-type, 'text/plain', 'chat magic set the mime type';
}

{
    my $code = q:to/DONE/;
    %% chat-re8989
    Please, re-write with the manager's name being Jane Doe, and start and end dates being 8/20 and 9/12.
    DONE

    ok my $magic = $m.find-magic($code), 'preprocess recognized %% chat';
    is $code.starts-with('Please, re-write'), True, 'content of the chat cell';
    my $r = $magic.preprocess($code);
    #note $r.output;

    # Dear <name>....
    is $r.output.contains('vacation', :i) && $r.output.contains('Jane', :i),
            True,
            'response contains "vacation" and "Jane"';

    is $r.output-mime-type, 'text/plain', 'chat magic set the mime type';
}

{
    my $code = q:to/DONE/;
    %% chat sdmaster > markdown
    Generate a System Dynamics model for production of artillery shells.
    DONE

    ok my $magic = $m.find-magic($code), 'preprocess recognized %% chat';
    is $code.starts-with('Generate a System Dynamics'), True, 'content of the chat cell';
    my $r = $magic.preprocess($code);
    #note $r.output;

    # Dear <name>....
    is $r.output.contains('model', :i),
            True,
            'response contains "model"';

    is $r.output-mime-type, 'text/markdown', 'chat magic set the mime type';
}

done-testing;