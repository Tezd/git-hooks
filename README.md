# Installation

## prepare-commit-msg 

        cp git/hooks/prepare-commit-msg.sh .git/hooks/prepare-commit-msg
        
## pre-commit

This hook will by default check only your changes to file. 
If you want it to check whole file set `CHECK_ALL_CHANGES` environment variable

Set up:
* Vagrant
    
            cp git/hooks/pre-commit.sh .git/hooks/pre-commit
            ssh-copy-id -p2222 vagrant@127.0.0.1 
            
    **Important** if you run `vagrant destroy` you need to rerun ssh-copy-id  
* Local php
        
    Comment out `#VAGRANT` section and uncomment `#LOCAL` and run
        
            cp git/hooks/pre-commit.sh .git/hooks/pre-commit
* Docker 
        
        coming soon :)
