# pgTAP "any results_eq"

I use [pgTAP](https://pgtap.org/) extensively and I enjoyed using it in my
MGT858 "Database Systems" class at Yale. While using pgTAP for grading I
encountered the need for a test that answers the following question: "do the
results of any of these N queries _match_ the results of these M queries?"
Usually I needed that because there were multiple ways to answer a question I
articulated in the homework. (That is to say, usually I was testing 1:M, rather
than N:M.). You can see [my post about this on the pgTAP mailing
list](https://groups.google.com/g/pgtap-users/c/sPX3jMPdV40).

Anyhooo...this is the solution I ended up with. You can see two functions
herein, one called `any_results_eq` and one called `any_set_eq`. They rely on
butchered version of functions from the [pgTAP
source](https://github.com/theory/pgtap) that I do not have the skill to write
_de novo_!

I'm putting this on GitHub in the hope that is useful to somebody else.

Code I wrote is [Unlicence](https://unlicense.org/). 

## Testing this

You should have pgtap installed in your PostgreSQL instance and you might
do something like

`psql -f ./test-any.sq`


