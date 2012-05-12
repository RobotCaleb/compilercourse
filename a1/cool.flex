/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */
int commentDepth = 0;

void SetCommentError(char *error);
void SetStringError(char *error);
bool StringTooLong(int length);
int AddToString(char* add);

%}

/* States */
%x COMMENT_SHORT
%x COMMENT_LONG

%x STRING
%x STR_ERROR

/*
 * Define names for regular expressions here.
 */

COMMENT_START                       "--"
COMMENT_LONG_START                  "(*"
COMMENT_LONG_END                    "*)"

DARROW                              "=>"
ASSIGN                              "<-"
LE                                  "<="

CLASS                               ?i:class
ELSE                                ?i:else
FI                                  ?i:fi
IF                                  ?i:if
IN                                  ?i:in
INHERITS                            ?i:inherits
ISVOID                              ?i:isvoid
LET                                 ?i:let
LOOP                                ?i:loop
POOL                                ?i:pool
THEN                                ?i:then
WHILE                               ?i:while
CASE                                ?i:case
ESAC                                ?i:esac
NEW                                 ?i:new
OF                                  ?i:of
NOT                                 ?i:not

 /* boolean */
TRUE                                t(?i:rue)
FALSE                               f(?i:alse)

 /* Numbers */
INTEGER         [0-9]+

 /* Identifiers */
TYPE                                [A-Z][a-zA-Z0-9_]*
OBJECT                              [a-z][a-zA-Z0-9_]*

%%

 /*
  *  The multiple-character operators.
  */
{DARROW}                            { return (DARROW); }
{ASSIGN}                            { return ASSIGN; }
{LE}                                { return LE; }

 /* comments */
{COMMENT_START}                     { BEGIN(COMMENT_SHORT); }
<COMMENT_SHORT>\n                   { curr_lineno++; BEGIN(INITIAL); }
<COMMENT_SHORT>.*                   /* NOTHING */

{COMMENT_LONG_END}                  { SetCommentError("Comment end without matching start"); return ERROR; }

{COMMENT_LONG_START}                { BEGIN(COMMENT_LONG); commentDepth++; }
<COMMENT_LONG>{COMMENT_LONG_START}  { commentDepth++; }
<COMMENT_LONG>{COMMENT_LONG_END}    {

                                       commentDepth--;
                                       if (commentDepth <= 0) BEGIN(INITIAL);
                                    }
<COMMENT_LONG>\n                    { curr_lineno++; }
<COMMENT_LONG>[^(\n\*]*             /* NOTHING */
<COMMENT_LONG>[(\*]                 /* NOTHING */
<COMMENT_LONG><<EOF>>               { SetCommentError("EOF in comment"); return ERROR; }

 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */

\"\"                                { cool_yylval.symbol = inttable.add_string(""); return STR_CONST; }
\"                                  { BEGIN(STRING); }
<STRING>\"                          {
                                        BEGIN(INITIAL);
                                        cool_yylval.symbol = inttable.add_string(string_buf);
                                        string_buf[0] = '\0';
                                        return STR_CONST;
                                    }
<STRING>[^\\\"\n\0]*                {
                                        if (AddToString(yytext) == ERROR) return ERROR;
                                    }
<STRING>\\b                         {
                                        if (AddToString("\b") == ERROR) return ERROR;
                                    }
<STRING>\\t                         {
                                        if (AddToString("\t") == ERROR) return ERROR;
                                    }
<STRING>\\n                         {
                                        if (AddToString("\n") == ERROR) return ERROR;
                                    }
<STRING>\\\n                        {
                                        if (AddToString("\n") == ERROR) return ERROR;
                                        curr_lineno++;
                                    }
<STRING>\\f                         {
                                        if (AddToString("\f") == ERROR) return ERROR;
                                    }
<STRING>\n                          {
                                        SetStringError("Unterminated string");
                                        string_buf[0] = '\0';
                                        curr_lineno++;
                                        BEGIN(INITIAL);
                                        return ERROR;
                                    }
<STRING>\\\0                        {
                                        SetStringError("Escaped NULL in string");
                                        string_buf[0] = '\0';
                                        return ERROR;
                                    }
<STRING>\\.                         {
                                        if (AddToString(yytext + 1) == ERROR) return ERROR;
                                    }
<STRING>\0                          {
                                        SetStringError("NULL in string");
                                        string_buf[0] = '\0';
                                        return ERROR;
                                    }
<STRING><<EOF>>                     {
                                        SetStringError("EOF in string");
                                        string_buf[0] = '\0';
                                        return ERROR;
                                    }


<STR_ERROR>[^\\\"\n]*             /* nothing */
<STR_ERROR>\n                       { BEGIN(INITIAL); curr_lineno++; }
<STR_ERROR>\"                       { BEGIN(INITIAL); }
<STR_ERROR>\\.                      /* nothing */
<STR_ERROR>\\\n                     { curr_lineno++; }

 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */
"="                                 { return (int)'='; }
"+"                                 { return (int)'+'; }
"-"                                 { return (int)'-'; }
"*"                                 { return (int)'*'; }
"/"                                 { return (int)'/'; }
"("                                 { return (int)'('; }
")"                                 { return (int)')'; }
"{"                                 { return (int)'{'; }
"}"                                 { return (int)'}'; }
";"                                 { return (int)';'; }
":"                                 { return (int)':'; }
"."                                 { return (int)'.'; }
","                                 { return (int)','; }
"<"                                 { return (int)'<'; }
"~"                                 { return (int)'~'; }
"@"                                 { return (int)'@'; }
            
{CLASS}                             { return (CLASS); }
{ELSE}                              { return (ELSE); }
{FI}                                { return (FI); }
{IF}                                { return (IF); }
{IN}                                { return (IN); }
{INHERITS}                          { return (INHERITS); }
{ISVOID}                            { return (ISVOID); }
{LET}                               { return (LET); }
{LOOP}                              { return (LOOP); }
{POOL}                              { return (POOL); }
{THEN}                              { return (THEN); }
{WHILE}                             { return (WHILE); }
{CASE}                              { return (CASE); }
{ESAC}                              { return (ESAC); }
{NEW}                               { return (NEW); }
{OF}                                { return (OF); }
{NOT}                               { return (NOT); }
            
{TRUE}                              { cool_yylval.boolean = 1; return (BOOL_CONST); }
{FALSE}                             { cool_yylval.boolean = 0; return (BOOL_CONST); }
                    
{INTEGER}                           { cool_yylval.symbol = inttable.add_string(yytext); return INT_CONST; }
                    
{TYPE}                              { cool_yylval.symbol = inttable.add_string(yytext); return TYPEID; }
{OBJECT}                            { cool_yylval.symbol = inttable.add_string(yytext); return OBJECTID; }
                
                
\n                                  { curr_lineno++; }
[ \r\t\v\f]                         /* nothing */
            
.                                   { cool_yylval.error_msg = strdup(yytext); return ERROR; }

%%

int AddToString(char* add)
{
    if (StringTooLong(strlen(add)))
    {
        return ERROR;
    }
    else
    {
        strcat(string_buf, add);
        return STR_CONST;
    }
}

bool StringTooLong(int length)
{
    int len = length + strlen(string_buf);
    if (len >= MAX_STR_CONST)
    {
        string_buf[0] = '\0';
        SetStringError("String too long");
        return true;
    }
    else
    {
        return false;
    }
}

void SetCommentError(char *error)
{
    BEGIN(INITIAL);
    cool_yylval.error_msg = error;
}

void SetStringError(char *error)
{
    BEGIN(STR_ERROR);
    cool_yylval.error_msg = error;
}