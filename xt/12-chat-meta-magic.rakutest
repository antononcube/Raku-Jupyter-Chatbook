#!/usr/bin/env perl6
use lib 'lib';
use Test;
use Log::Async;
use Jupyter::Chatbook::Magics;
use LLM::Prompts;

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
    %% chat-re8989 meta
    Str
    DONE

    ok my $magic = $m.find-magic($code), 'preprocess recognized %% chat meta';
    is $code, "Str\n", 'content of the chat meta cell';
    my $r = $magic.preprocess($code);
    #note $r.output;

    is $r.output.contains('vacation', :i),
            True,
            'response contains "vacation" and "Jane"';

    is $r.output-mime-type, 'text/plain', 'chat meta magic set the mime type';
}

{
    my $code = q:to/DONE/;
    %% chat all
    keys
    DONE

    ok my $magic = $m.find-magic($code), 'preprocess recognized %% chat meta';
    is $code, "keys\n", 'content of the chat meta cell';
    my $r = $magic.preprocess($code);
    #note $r.output;

    is $r.output.contains('re8989', :i),
            True,
            'response contains "re8989"';

    is $r.output-mime-type, 'text/plain', 'chat all magic set the mime type';
}

{
    my $code = q:to/DONE/;
    %% chat-yoda1 prompt
    @Yoda
    DONE

    ok my $magic = $m.find-magic($code), 'preprocess recognized %% chat';
    is $code, "@Yoda\n", 'content of the chat cell';
    my $r = $magic.preprocess($code);
    #note $r.output;
    # Dear <name>....
    is $r.output.contains('You are Yoda'):i, True, 'response contains "You are Yoda"';
    is $r.output-mime-type, 'text/plain', 'chat magic set the mime type';
}

{
    my $code = q:to/DONE/;
    %% chat-yoda2 prompt conf=ChatGPT
    @Yoda
    DONE

    ok my $magic = $m.find-magic($code), 'preprocess recognized %% chat';
    is $code, "@Yoda\n", 'content of the chat cell';
    my $r = $magic.preprocess($code);
    #note $r.output;
    # Dear <name>....
    is $r.output.contains('You are Yoda'):i, True, 'response contains "You are Yoda"';
    is $r.output-mime-type, 'text/plain', 'chat magic set the mime type';
}

{
    my $code = q:to/DONE/;
    %% chat-yoda3, conf=ChatPaLM
    @Yoda Hi! Who are you?
    DONE

    ok my $magic = $m.find-magic($code), 'preprocess recognized %% chat-yoda1';
    is $code.contains('@Yoda'), True, 'content of the chat cell';
    my $r = $magic.preprocess($code);
    #note $r.output;
    # Dear <name>....
    is $r.output.contains('I am Yoda'):i, True, 'response contains "I am Yoda"';
    is $r.output-mime-type, 'text/plain', 'chat magic set the mime type';
}

{
    my $code = q:to/DONE/;
    %% chat yoda3 meta
    drop
    DONE

    ok my $magic = $m.find-magic($code), 'preprocess recognized %% chat-yoda1';
    my $r = $magic.preprocess($code);
    #note $r.output;
    # Dear <name>....
    is $r.output.contains('Delete'):i, True, 'response contains "I am Yoda"';
    is $r.output-mime-type, 'text/plain', 'chat magic set the mime type';
}

{
    my $code = q:to/DONE/;
    %% chat yoda4 conf='ChatPaLM'
    @Yoda Hi! Who are you?
    DONE

    ok my $magic = $m.find-magic($code), 'preprocess recognized %% chat-yoda1';
    is $code.contains('@Yoda'), True, 'content of the chat cell';
    my $r = $magic.preprocess($code);
    #note $r.output;
    # Dear <name>....
    is $r.output.contains('I am Yoda'):i, True, 'response contains "I am Yoda"';
    is $r.output-mime-type, 'text/plain', 'chat magic set the mime type';
}

{
    my $code = q:to/DONE/;
    %% chat yoda4 drop
    DONE

    ok my $magic = $m.find-magic($code), 'preprocess recognized %% chat-yoda1';
    my $r = $magic.preprocess($code);
    #note $r.output;
    # Dear <name>....
    is $r.output.contains('Delete'):i, True, 'response contains "I am Yoda"';
    is $r.output-mime-type, 'text/plain', 'chat magic set the mime type';
}

done-testing;