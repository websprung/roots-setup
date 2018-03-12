### ruby roots_setup.rb --help ###

```
    -h, --help                       Show this help message
    -s, --site-url=URL               The url of the client site address eg "coolproject.com"
    -o, --organisation-url=URL       your organisations url name eg "websprung.com"
    -p, --mail-password=PASSWORD     mail password (leave blank to have one auto generated)
    -m, --mail-service=SERVICE       transactional email service can be: "mailgun", "sendgrid" (defaults to: mailgun)
    -a, --acf-key=KEY                OPTIONAL Advanced Custom Fields license key if available. Leave blank to skip this part of setup
    -t, --roots-repo=USERNAME        OPTIONAL alternative repository to pull trellis + bedrock from. defaults to "roots"
    -g, --github-usernames=foo,bar   OPTIONAL github usernames comma seperated to retrieve public keys (will default to local public keys if left blank).
    -r, --repo=REPO                  OPTIONAL select remote repository. will setup remote using organisation name. leave blank to skip. can be "bitbucket" or "github"
```

### how to use ###

download into your sites folder (or whatever folder you keep sites/projects)

for most basic setup, run the following within the downloaded folder:

```
ruby roots_setup.rb -s coolproject.com -o websprung.com -m mailgun -r bitbucket
```

This create a new project for coolproject.com with organisation websprung.com, using mailgun, with bitbucket as the repo. All salts and passwords will be autogenarated along with a `.vault_pass` which is then used to encrypt all vault files.

#### -r --repo ####

with this option filled in, `git@github.com:example/example.com.git` is set to `git@bitbucket.com:websprung/coolproject.com.git`

In addition, this remote is added to .gitconfig (remember to create it in bitbucket/github after!!)

#### -m --mail-service ####
mail settings will be changed to:
```
smtp.example.com:587 => smtp.mailgun.com:587
admin@example.com    => coolproject@mg.webspung.com
smtp_user            => coolproject@mg.webspung.com
```
or sendgrid if sendgrid is made the option.

#### -a --acf-key ####

acf_pro_key is added into all environments (development/staging/production in the vault files.

#### -g --github-usernames ####

github usernames will be looped and added into users.yml. if more than one, separate with a comma and no spaces.

#### -t --roots-repo ####

use this to override the default repositories for trellis and roots <https://github.com/roots>

#### Extras ####
if you create a `readme_template.md` file, this will be copied over into the new project root.
