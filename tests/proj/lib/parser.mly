/* header */
%{
%}

/* token declarations */
%token EOF

/* start symbol */
%start main

/* types */
%type <unit> main

%%

/* production rules */
main:
  | EOF { let in_parser = () in in_parser }

%%
