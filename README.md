# package-json-dependency-audit

Basically if you have multiple apps in a code base you have a lot of modules laying around. Wouldn't it be nice if you knew what you had? And if you were going to add more, wouldn't it be nice to see if you had module versions elsewhere in the code or if they were new? Enter this hacked together script. Uses no external modules to avoid extra setup, but yes performance isn't as good as it could be as a result.

For a sample, I browsed GitHub for a few React applications and dumped them into a folder called 'sampleCodeDir'. Then I can invoke this to get a list of dependencies across the board:

```
perl package-json-depdency-audit.pl sampleCodeDir
```

Now I added one more and told the script it was something I wanted to add. Then I get a fourth file that lists the versions we already have (or none) of every dependency inside the package.json specified by 'new-package-json':

```
perl package-json-depdency-audit.pl sampleCodeDir --new-package-json=sampleCodeDir/newApp/package.json
```

Default output goes inside /tmp/package-json-audit/ unless you give script another path. Options show up via invoking '--help' (displays perldoc).

```
perl package-json-depdency-audit.pl --help
```
