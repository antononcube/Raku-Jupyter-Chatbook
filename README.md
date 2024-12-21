# Jupyter::Chatbook

[![MacOS](https://github.com/antononcube/Raku-Jupyter-Chatbook/actions/workflows/macos.yml/badge.svg)](https://github.com/antononcube/Raku-Jupyter-Chatbook/actions/workflows/macos.yml)
[![Linux](https://github.com/antononcube/Raku-Jupyter-Chatbook/actions/workflows/linux.yml/badge.svg)](https://github.com/antononcube/Raku-Jupyter-Chatbook/actions/workflows/linux.yml)
[![https://raku.land/zef:antononcube/Jupyter::Chatbook](https://raku.land/zef:antononcube/Jupyter::Chatbook/badges/version)](https://raku.land/zef:antononcube/Jupyter::Chatbook)

## In brief

This Raku package is a fork of Brian Duggan's 
["Jupyter::Kernel"](https://github.com/bduggan/raku-jupyter-kernel), [BDp1].

Here are the top opening statements of the README of "Jupyter::Kernel":

> "Jupyter::Kernel" is a pure Raku implementation of a Raku kernel for Jupyter clients¹.

> Jupyter notebooks provide a web-based (or console-based)
Read Eval Print Loop (REPL) for running code and serializing input and output.

It is desirable to include the interaction with Large Language Models (LLMs) into 
the "typical" REPL systems or workflows. Having LLM-aware and LLM-chat-endowed 
notebooks -- **chatbooks** -- can really speed up the:
- Writing and preparation of documents on variety of subjects
- Derivation of useful programming code
- Adoption of programming languages by newcomers

This repository is mostly for experimental work, but it aims to be *always* very
useful for interacting with LLMs via Raku.

**Remark:** The reason to have a separate package -- a fork of
["Jupyter::Kernel"](https://github.com/bduggan/raku-jupyter-kernel) --
is because:
- I plan to introduce 4-6 new package dependencies
- I expect to do a fair amount of UX experimental implementations and refactoring

-------

## Installation and setup

From ["Zef ecosystem"](https://raku.land):

```
zef install Jupyter::Chatbook
```

From GitHub:

```
zef install https://github.com/antononcube/Raku-Jupyter-Chatbook.git
```

### macOS specific

If using macOS and [ZMQ](https://zeromq.org) is installed with [homebrew](https://formulae.brew.sh/formula/zeromq), 
then it might be necessary to copy the ZMQ library "libzmq.5.dylib" into a directory where `zef` can find it.

For example, see the GitHub Actions workflow file ["macos.yml"](https://github.com/antononcube/Raku-Jupyter-Chatbook/blob/master/.github/workflows/macos.yml). 

-------

## Jupyter kernel configuration

**Remark:** The instructions in this section follow the instructions in
["Jupyter::Kernel"](https://github.com/bduggan/raku-jupyter-kernel).
The "main" change is using `jupyter-chatbook.raku` instead of `jupyter-kernel.raku`. 

### Server Configuration

To generate a configuration directory, and to install a kernel
config file and icons into the default location:

```
jupyter-chatbook.raku --generate-config
```

* Use `--location=XXX` to specify another location.
* Use `--force` to override an existing configuration.

### Logging

By default a log file `jupyter.log` will be written in the
current directory.  An option `--logfile=XXX` argument can be
added to the argv argument of the server configuration file
(located at `$(jupyter --data)/kernels/raku/kernel.json`)
to change this.

### Client configuration

The jupyter documentation describes the client configuration.
To start, you can generate files for the notebook or
console clients like this:

```
jupyter notebook --generate-config
jupyter console --generate-config
```

Some suggested configuration changes for the console client:

* set `kernel_is_complete_timeout` to a high number.  Otherwise,
  if the kernel takes more than 1 second to respond, then from
  then on, the console client uses internal (non-Raku) heuristics
  to guess when a block of code is complete.

* set `highlighting_style` to `vim`.  This avoids having dark blue
  on a black background in the console client.

### Running

Start the web UI with:

```
jupyter-notebook
Then select New -> Raku.
```

You can also use it in the console like this:

```
jupyter-console --kernel=raku
```

Or make a handy shell alias:

```
alias iraku='jupyter-console --kernel=raku'
```

### macOS specific

Consider copying the 
[RakuChatbook kernel specifications](./resources) 
in the directory "~/Library/Jupyter/kernels/raku". That way IDEs like 
[Visual Studio Code](https://code.visualstudio.com)
would find the "RakuChatbook" kernel "quicker" or "more directly." 

------

## LLM, DeepL, and WolframAlpha API keys

The default API keys for the chat cells, LLM functions, chat objects, and DeepL cells are taken from 
the Operating System (OS) environmental variables 
`OPENAI_API_KEY`, `PALM_API_KEY`, `GEMINI_API_KEY`, `MISTRAL_API_KEY`, `DEEPL_AUTH_KEY`, `WOLFRAM_ALPHA_API_KEY`. 

The API keys can also be specified using LLM evaluator and configuration options and objects; 
see [AA3, AAp2, AAv4].

**Remark:** `PALM_API_KEY` works for both PaLM and Gemini.

-------

## Using LLMs in chatbooks

There are four ways to use LLMs in a chatbook:

1. [LLM functions](https://github.com/antononcube/Raku-Jupyter-Chatbook/blob/master/eg/Chatbook-LLM-functions-and-chat-objects.ipynb), [AA3, AAp2]
2. [LLM chat objects](https://github.com/antononcube/Raku-Jupyter-Chatbook/blob/master/eg/Chatbook-LLM-functions-and-chat-objects.ipynb), [AA4, AAp2]
3. [Code cells with magics](https://github.com/antononcube/Raku-Jupyter-Chatbook/blob/master/eg/Chatbook-LLM-cells.ipynb)
   accessing LLMs, like, OpenAI's, [AAp3], or PaLM's, [AAp4]
4. [Notebook-wide chats](https://github.com/antononcube/Raku-Jupyter-Chatbook/blob/master/eg/Chatbook-LLM-chats.ipynb) 
   that are distributed over multiple code cells with chat-magic specs

The sections below briefly describe each of these ways and have links to notebooks with
more detailed examples.

-------

## LLM functions and chat objects

LLM functions as described in [AA3] are best utilized via a certain REPL tool or environment.
Notebooks are the perfect media for LLM functions workflows. 
Here is an example of a code cell that defines an LLM function:

```perl6
use LLM::Functions;

my &fcp = llm-function({"What is the population of the country $_ ?"});
```
```
# -> **@args, *%args { #`(Block|3736847888056) ... }
```

Here is another cell that can be evaluated multiple times using different country names:

```perl6
<Niger Gabon>.map({ &fcp($_) })
```
```
# (As of 2021, the population of Niger is estimated to be around 25 million. According to the latest United Nations data, the population of Gabon is approximately 2.2 million as of 2021.)
```

For more examples of LLM functions and LLM chat objects see the notebook 
["Chatbook-LLM-functions-and-chat-objects.ipynb"](https://github.com/antononcube/Raku-Jupyter-Chatbook/blob/master/eg/Chatbook-LLM-functions-and-chat-objects.ipynb).

**Remark:** 
Chatbooks load in their initialization phase the packages
["LLM::Functions"](https://github.com/antononcube/Raku-LLM-Functions), [AAp2], and
["LLM::Prompts"](https://github.com/antononcube/Raku-LLM-Prompts), [AAp10].
"LLM::Prompts" provides a prompt expansion DSL that allows specifications like:

```
#% chat
@Yoda How many students did you train? #Translated|German
```

See the movie ["Jupyter Chatbook multi cell LLM chats teaser (Raku)"](https://www.youtube.com/watch?v=wNpIGUAwZB8), [AAv5].

**Remark:**
Also, in the initialization phase are loaded the packages
["Clipboard"](https://github.com/antononcube/Raku-Clipboard), [AAp5],
["Data::Translators"](https://github.com/antononcube/Raku-Data-Translators), [AAp6],
["Data::TypeSystem"](https://github.com/antononcube/Raku-Data-Translators), [AAp7],
["Text::Plot"](https://github.com/antononcube/Raku-Text-Plot), [AAp8],
and
["Text::SubParsers"](https://github.com/antononcube/Raku-Text-SubParsers), [AAp9],
that can be used to post-process LLM outputs.

-------

## LLM cells

The LLMs of OpenAI (ChatGPT, DALL-E) and Google (PaLM, Gemini) can be interacted with using "dedicated" notebook cells.

Here is an example of a code cell with PaLM magic spec:

```
%% gemini, max-tokens=600
Generate a horror story about a little girl lost in the forest and getting possessed.
```

For more examples see the notebook 
["Chatbook-LLM-cells.ipynb"](https://github.com/antononcube/Raku-Jupyter-Chatbook/blob/master/eg/Chatbook-LLM-cells.ipynb).

------

## Notebook-wide chats

Chatbooks have the ability to maintain LLM conversations over multiple notebook cells.
A chatbook can have more than one LLM conversations.
"Under the hood" each chatbook maintains a database of chat objects.
Chat cells are used to give messages to those chat objects.

For example, here is a chat cell with which a new 
["Email writer"](https://developers.generativeai.google/prompts/email-writer) 
chat object is made, and that new chat object has the identifier "em12":  

```
%% chat-em12, prompt = «Given a topic, write emails in a concise, professional manner»
Write a vacation email.
```

Here is a chat cell in which another message is given to the chat object with identifier "em12":

```
%% chat-em12
Rewrite with manager's name being Jane Doe, and start- and end dates being 8/20 and 9/5.
```

In this chat cell a new chat object is created:

```
%% chat snowman, prompt = ⎡Pretend you are a friendly snowman. Stay in character for every response you give me. Keep your responses short.⎦
Hi!
```

And here is a chat cell that sends another message to the "snowman" chat object:

```
%% chat snowman
Who build you? Where?
```

**Remark:** Specifying a chat object identifier is not required. I.e. only the magic spec `%% chat` can be used.
The "default" chat object ID identifier is "NONE".

**Remark:** The magic keyword "chat" can be separated from the identifier of the chat object with
the symbols "-", "_", ":", or with any number of (horizontal) white spaces.

For more examples see the notebook 
["Chatbook-LLM-chats.ipynb"](https://github.com/antononcube/Raku-Jupyter-Chatbook/blob/master/eg/Chatbook-LLM-chats.ipynb).
For a quick demo see the movie
["Jupyter Chatbook multi cell LLM chats teaser (Raku)"](https://www.youtube.com/watch?v=wNpIGUAwZB8), [AAv5].

Here is a flowchart that summarizes the way chatbooks create and utilize LLM chat objects:

```mermaid
flowchart LR
    OpenAI{{OpenAI}}
    Gemini{{Gemini}}
    LLaMA{{LLaMA}}
    LLMFunc[[LLM::Functions]]
    LLMProm[[LLM::Prompts]]
    CODB[(Chat objects)]
    PDB[(Prompts)]
    CCell[/Chat cell/]
    CRCell[/Chat result cell/]
    CIDQ{Chat ID<br/>specified?}
    CIDEQ{Chat ID<br/>exists in DB?}
    RECO[Retrieve existing<br/>chat object]
    COEval[Message<br/>evaluation]
    PromParse[Prompt<br/>DSL spec parsing]
    KPFQ{Known<br/>prompts<br/>found?}
    PromExp[Prompt<br/>expansion]
    CNCO[Create new<br/>chat object]
    CIDNone["Assume chat ID<br/>is 'NONE'"] 
    subgraph Chatbook frontend    
        CCell
        CRCell
    end
    subgraph Chatbook backend
        CIDQ
        CIDEQ
        CIDNone
        RECO
        CNCO
        CODB
    end
    subgraph Prompt processing
        PDB
        LLMProm
        PromParse
        KPFQ
        PromExp 
    end
    subgraph LLM interaction
      COEval
      LLMFunc
      Gemini
      LLaMA
      OpenAI
    end
    CCell --> CIDQ
    CIDQ --> |yes| CIDEQ
    CIDEQ --> |yes| RECO
    RECO --> PromParse
    COEval --> CRCell
    CIDEQ -.- CODB
    CIDEQ --> |no| CNCO
    LLMFunc -.- CNCO -.- CODB
    CNCO --> PromParse --> KPFQ
    KPFQ --> |yes| PromExp
    KPFQ --> |no| COEval
    PromParse -.- LLMProm 
    PromExp -.- LLMProm
    PromExp --> COEval 
    LLMProm -.- PDB
    CIDQ --> |no| CIDNone
    CIDNone --> CIDEQ
    COEval -.- LLMFunc
    LLMFunc <-.-> OpenAI
    LLMFunc <-.-> Gemini
    LLMFunc <-.-> LLaMA
```

------

## Chat meta cells

Each chatbook session has a Hash of chat objects.
Chatbooks can have chat meta cells that allow the access of the chat object "database" as whole, 
or its individual objects.  

Here is an example of a chat meta cell (that applies the method `say` to the chat object with ID "snowman"):

```
%% chat snowman meta
say
```

Here is an example of chat meta cell that creates a new chat chat object with the LLM prompt
specified in the cell
(["Guess the word"](https://developers.generativeai.google/prompts/guess-the-word)):

```
%% chat-WordGuesser prompt
We're playing a game. I'm thinking of a word, and I need to get you to guess that word. 
But I can't say the word itself. 
I'll give you clues, and you'll respond with a guess. 
Your guess should be a single word only.
```

Here is another chat object creation cell using a prompt from the package
["LLM::Prompts"](https://raku.land/zef:antononcube/LLM::Prompts), [AAp4]:

```
%% chat yoda1 prompt
@Yoda
```

Here is a table with examples of magic specs for chat meta cells and their interpretation:

| cell magic line  | cell content                         | interpretation                                                  |
|:-----------------|:-------------------------------------|:----------------------------------------------------------------|
| chat-ew12 meta   | say                                  | Give the "print out" of the chat object with ID "ew12"          |   
| chat-ew12 meta   | messages                             | Give the messages of the chat object with ID "ew12"             |   
| chat sn22 prompt | You pretend to be a melting snowman. | Create a chat object with ID "sn22" with the prompt in the cell |   
| chat meta all    | keys                                 | Show the keys of the session chat objects DB                    |   
| chat all         | keys                                 | *«same as above»*                                               |   

Here is a flowchart that summarizes the chat meta cell processing:

```mermaid
flowchart LR
    LLMFunc[[LLM::Functions]]
    CODB[(Chat objects)]
    CCell[/Chat meta cell/]
    CRCell[/Chat meta cell result/]
    CIDQ{Chat ID<br/>specified?}
    KCOMQ{Known<br/>chat object<br/>method?}
    AKWQ{Keyword 'all'<br/>specified?} 
    KCODBMQ{Known<br/>chat objects<br/>DB method?}
    CIDEQ{Chat ID<br/>exists in DB?}
    RECO[Retrieve existing<br/>chat object]
    COEval[Chat object<br/>method<br/>invocation]
    CODBEval[Chat objects DB<br/>method<br/>invocation]
    CNCO[Create new<br/>chat object]
    CIDNone["Assume chat ID<br/>is 'NONE'"] 
    NoCOM[/Cannot find<br/>chat object<br/>message/]
    CntCmd[/Cannot interpret<br/>command<br/>message/]
    subgraph Chatbook
        CCell
        NoCOM
        CntCmd
        CRCell
    end
    CCell --> CIDQ
    CIDQ --> |yes| CIDEQ  
    CIDEQ --> |yes| RECO
    RECO --> KCOMQ
    KCOMQ --> |yes| COEval --> CRCell
    KCOMQ --> |no| CntCmd
    CIDEQ -.- CODB
    CIDEQ --> |no| NoCOM
    LLMFunc -.- CNCO -.- CODB
    CNCO --> COEval
    CIDQ --> |no| AKWQ
    AKWQ --> |yes| KCODBMQ
    KCODBMQ --> |yes| CODBEval
    KCODBMQ --> |no| CntCmd
    CODBEval -.- CODB
    CODBEval --> CRCell
    AKWQ --> |no| CIDNone
    CIDNone --> CIDEQ
    COEval -.- LLMFunc
```

-------

## [DeepL](https://www.deepl.com) cells

Chatbooks can have [DeepL](https://www.deepl.com) cells (that use the package 
["Lingua::Translation::DeepL"](https://raku.land/zef:antononcube/Lingua::Translation::DeepL),
[AAp15].)
For example:

```
#% deepl, to-lang=German, formality=less, format=text
I told you to get the frames from the other warehouse!
```

```
Ich habe dir gesagt, du sollst die Rahmen aus dem anderen Lager holen!
```

-------

## [Mermaid-JS](https://mermaid.js.org) cells

Chatbooks can have [Mermaid-JS](https://mermaid.js.org) cells,
(that use the package ["WWW::MermaidInk"](https://raku.land/zef:antononcube/WWW::MermaidInk), [AAp11].)
For example:

```
#% mermaid, format=svg, background=SlateGray
mindmap
**Chatbook**
    **Direct LLM access**
        OpenAI
            ChatGPT
            DALL-E
        Google
            PaLM
            Gemini
        MistralAI
        LLaMA
    **Notebook wide chats**
        Chat objects
           Named
           Anonymous
        Chat meta cells              
        Prompt DSL expansion 
    **DeepL**
    **MermaidJS**
        SVG
        PNG
    **Pre-loaded packages**
        LLM::Functions
        LLM::Prompts
        Text::SubParsers
        Data::Translators
        Data::TypeSystem
        Clipboard :ALL
        Text::Plot
        Image::Markup::Utilities
        WWW::LLaMA
        WWW::MermaidInk
        WWW::OpenAI
        WWW::PaLM
        WWW::Gemini
        Lingua::Translation::DeepL
```

------

## Docker 

Thanks for @ab5tract there are two Docker files:

1. [Dockerfile](./Dockerfile)
2. [Dockerfile.rakudo-HEAD](./Dockerfile.rakudo-HEAD)

The first is for a "standard" run; the second builds Rakudo.

Create the "core" image [`rchat:1.0`](./Dockerfile.rakudo-HEAD) on Linux with:

```
docker build -f Dockerfile.rakudo-HEAD -t rchat:1.0 .
```

Run a container `chatbook` based on the image `rchat:1.0`:

```
docker run --rm -p 8888:8888 --name chatbook -t rchat:1.0
```

------

## TODO

1. [ ] TODO Features
   1. [X] DONE Chat-meta cells (simple)
      - [X] DONE meta  
      - [X] DONE all  
      - [X] DONE prompt
   2. [X] DONE Gemini cells
   3. [X] DONE LLaMA cells
   4. [X] DONE DeepL cells
   5. [X] DONE Wolfram|Alpha cells
      - Handling cell type: result, simple, or query
   6. [ ] TODO Chat-meta cells (via LLM)
   7. [ ] TODO DSL ["ProdGDT"](https://github.com/antononcube/Raku-WWW-ProdGDT) cells
   8. [X] DONE Using pre-prepared prompts
      - This requires implementing ["LLM::Prompts"](https://github.com/antononcube/Raku-LLM-Prompts).
        - And populating it with a good number of prompts.
   9. [ ] TODO Parse Python style magics
      - See ["JupyterChatbook"](https://github.com/antononcube/Python-JupyterChatbook)
      - See ["Getopt::Long::Grammar"](https://github.com/antononcube/Raku-Getopt-Long-Grammar)
2. [ ] TODO Unit tests
   1. [X] DONE PaLM cells
   2. [X] DONE OpenAI cells
   3. [X] DONE MermaidInk cells
   4. [ ] TODO DALL-E cells
   5. [X] DONE Chat meta cells
3. [ ] TODO Documentation
   - [X] DONE LLM functions and chat objects in chatbooks
   - [X] DONE LLM cells in chatbooks
   - [X] DONE Notebook-wide chats and chat meta cells 
   - [X] DONE Introductory video(s)
   - [ ] TODO All parameters of OpenAI API in Raku
   - [ ] TODO All parameters of PaLM API in Raku
   - [ ] TODO More details on prompts

------

## References

### Articles

[AA1] Anton Antonov,
["Literate programming via CLI"](https://rakuforprediction.wordpress.com/2023/03/06/literate-programming-via-cli/),
(2023),
[RakuForPrediction at WordPress](https://rakuforprediction.wordpress.com).

[AA2] Anton Antonov,
["Generating documents via templates and LLMs"](https://rakuforprediction.wordpress.com/2023/07/11/generating-documents-via-templates-and-llms/),
(2023),
[RakuForPrediction at WordPress](https://rakuforprediction.wordpress.com).

[AA3] Anton Antonov,
["Workflows with LLM functions"](https://rakuforprediction.wordpress.com/2023/08/01/workflows-with-llm-functions/),
(2023),
[RakuForPrediction at WordPress](https://rakuforprediction.wordpress.com).

[AA4] Anton Antonov,
["Number guessing games: PaLM vs ChatGPT"](https://rakuforprediction.wordpress.com/2023/08/06/number-guessing-games-palm-vs-chatgpt/),
(2023),
[RakuForPrediction at WordPress](https://rakuforprediction.wordpress.com).

[AA5] Anton Antonov,
["Chatbook New Magic Cells"](https://rakuforprediction.wordpress.com/2024/05/18/chatbook-new-magic-cells),
(2024),
[RakuForPrediction at WordPress](https://rakuforprediction.wordpress.com).

[SW1] Stephen Wolfram,
["Introducing Chat Notebooks: Integrating LLMs into the Notebook Paradigm"](https://writings.stephenwolfram.com/2023/06/introducing-chat-notebooks-integrating-llms-into-the-notebook-paradigm/),
(2023),
[writings.stephenwolfram.com](https://writings.stephenwolfram.com).

### Packages

[AAp1] Anton Antonov,
[Jupyter::Chatbook Raku package](https://github.com/antononcube/Raku-Jupyter-Chatbook),
(2023),
[GitHub/antononcube](https://github.com/antononcube).

[AAp2] Anton Antonov,
[LLM::Functions Raku package](https://github.com/antononcube/Raku-LLM-Functions),
(2023),
[GitHub/antononcube](https://github.com/antononcube).

[AAp3] Anton Antonov,
[WWW::OpenAI Raku package](https://github.com/antononcube/Raku-WWW-OpenAI),
(2023),
[GitHub/antononcube](https://github.com/antononcube).

[AAp4] Anton Antonov,
[WWW::PaLM Raku package](https://github.com/antononcube/Raku-WWW-PaLM),
(2023),
[GitHub/antononcube](https://github.com/antononcube).

[AAp5] Anton Antonov,
[Clipboard Raku package](https://github.com/antononcube/Raku-Clipboard),
(2023),
[GitHub/antononcube](https://github.com/antononcube).

[AAp6] Anton Antonov,
[Data::Translators Raku package](https://github.com/antononcube/Raku-Data-Translators),
(2023),
[GitHub/antononcube](https://github.com/antononcube).

[AAp7] Anton Antonov,
[Data::TypeSystem Raku package](https://github.com/antononcube/Raku-Data-TypeSystem),
(2023),
[GitHub/antononcube](https://github.com/antononcube).

[AAp8] Anton Antonov,
[Text::Plot Raku package](https://github.com/antononcube/Raku-Text-Plot),
(2022),
[GitHub/antononcube](https://github.com/antononcube).

[AAp9] Anton Antonov,
[Text::SubParsers Raku package](https://github.com/antononcube/Raku-Text-SubParsers),
(2023),
[GitHub/antononcube](https://github.com/antononcube).

[AAp10] Anton Antonov,
[LLM::Prompts Raku package](https://github.com/antononcube/Raku-LLM-Prompts),
(2023),
[GitHub/antononcube](https://github.com/antononcube).

[AAp11] Anton Antonov,
[WWW::MermaidInk Raku package](https://github.com/antononcube/Raku-WWW-MermaidInk),
(2023),
[GitHub/antononcube](https://github.com/antononcube).

[AAp12] Anton Antonov,
[WWW::MistralAI Raku package](https://github.com/antononcube/Raku-WWW-MistralAI),
(2023),
[GitHub/antononcube](https://github.com/antononcube).

[AAp13] Anton Antonov,
[WWW::LLaMA Raku package](https://github.com/antononcube/Raku-WWW-LLaMA),
(2024),
[GitHub/antononcube](https://github.com/antononcube).

[AAp14] Anton Antonov,
[WWW::Gemini Raku package](https://github.com/antononcube/Raku-WWW-Gemini),
(2024),
[GitHub/antononcube](https://github.com/antononcube).

[AAp15] Anton Antonov,
[Lingua::Translation::DeepL Raku package](https://github.com/antononcube/Raku-Lingua-Translation-DeepL),
(2022),
[GitHub/antononcube](https://github.com/antononcube).

[AAp16] Anton Antonov,
[WWW::WolframAlpha Raku package](https://github.com/antononcube/Raku-WWW-WolframAlpha),
(2024),
[GitHub/antononcube](https://github.com/antononcube).

[BDp1] Brian Duggan,
[Jupyter:Kernel Raku package](https://github.com/bduggan/raku-jupyter-kernel),
(2017-2023),
[GitHub/bduggan](https://github.com/bduggan).

### Videos

[AAv1] Anton Antonov,
["Raku Literate Programming via command line pipelines"](https://www.youtube.com/watch?v=2UjAdQaKof8),
(2023),
[YouTube/@AAA4Prediction](https://www.youtube.com/@AAA4prediction).

[AAv2] Anton Antonov,
["Racoons playing with pearls and onions"](https://www.youtube.com/watch?v=zlkoNZK8MpU)
(2023),
[YouTube/@AAA4Prediction](https://www.youtube.com/@AAA4prediction).

[AAv3] Anton Antonov,
["Streamlining ChatGPT code generation and narration workflows (Raku)"](https://www.youtube.com/watch?v=mI-oWLz5dYY)
(2023),
[YouTube/@AAA4Prediction](https://www.youtube.com/@AAA4prediction).

[AAv4] Anton Antonov,
["Jupyter Chatbook LLM cells demo (Raku)"](https://www.youtube.com/watch?v=cICgnzYmQZg)
(2023),
[YouTube/@AAA4Prediction](https://www.youtube.com/@AAA4prediction).

[AAv5] Anton Antonov,
["Jupyter Chatbook multi cell LLM chats teaser (Raku)"](https://www.youtube.com/watch?v=wNpIGUAwZB8)
(2023),
[YouTube/@AAA4Prediction](https://www.youtube.com/@AAA4prediction).


------

## *Footnotes*

¹ Jupyter clients are user interfaces to interact with an interpreter kernel like "Jupyter::Chatbook".
Jupyter [Lab | Notebook | Console | QtConsole ] are the jupyter maintained clients.
More info in the [Jupyter documentation site](https://jupyter.org/documentation).
