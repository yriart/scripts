# git-purge-branches
#
# * Will delete all fully merged local branches
#   and any closed remote branches.
# * User is prompted to continue before deleting.
# * Pass in -d or --dry-run to see what would happen without changing anything
# * Pass in -s or --stale to include all branches with no commits in the
#   past 6 months, even if they are not fully merged.
#
# Credit to Rob Miller <rob@bigfish.co.uk>
# Adapted from the original by Yorick Sijsling
# See: https://gist.github.com/robmiller/5133264
# Authors John Schank, Lisa Yriart

function git-purge-branches --description="Delete all fully merged and/or stale local and remote branches"
    for option in $argv
        switch "$option"
            case -d --dry-run
                set DRY_RUN true
            case -s --stale
                set PURGE_STALE true
            case \*
                printf "Error: unknown option %s\n" $option
        end
    end

    #  Make sure we're on master first
    git checkout master > /dev/null ^&1

    # Make sure we're working with the most up-to-date version of master.
    git fetch

    # Prune obsolete remote tracking branches. These are branches that we
    # once tracked, but have since been deleted on the remote.
    git remote prune origin

    # List all the branches that have been merged fully into master, and
    # then delete them. We use the remote master here, just in case our
    # local master is out of date.
    set -l MERGED_LOCAL (git branch --merged origin/master | grep -v 'master$' | string trim)
    if test -n "$MERGED_LOCAL"
        echo
        echo "The following local branches are fully merged and will be removed:"
        echo $MERGED_LOCAL
        read --local --prompt-str "Continue (y/N)? " REPLY
        if test "$REPLY" = "y"
            for branch in $MERGED_LOCAL
                if test $DRY_RUN
                    echo "Would delete local branch: '$branch'"
                else
                    echo "Deleting local branch: '$branch'"
                    git branch --quiet --delete $branch
                end
            end
        end
    end

    # Now the same, but including remote branches.
    set -l MERGED_ON_REMOTE (git branch -r --merged origin/master | sed 's/ *origin\///' | grep -v 'master$')

    if test -n "$MERGED_ON_REMOTE"
        echo
        echo "The following remote branches are fully merged and will be removed:"
        echo $MERGED_ON_REMOTE
        read --local --prompt-str "Continue (y/N)? " REPLY
        if test "$REPLY" = "y"
            for branch in $MERGED_ON_REMOTE
                if test $DRY_RUN
                    echo "Would delete remote branch: '$branch'"
                else
                    echo "Deleting remote branch: '$branch'"
                    git push --quiet origin :$branch
                end
            end
        end
    end

    # List all branches that have not had commits within the last 6
    # months, and then delete them.
    if test -n "$PURGE_STALE"
        set -l ALL_BRANCHES (git branch -r | grep -v 'master$' | string trim)
        set -l STALE_BRANCHES
        for branch in $ALL_BRANCHES
            if test (git log $branch --since "6 months ago" | wc -l) = 0
                set -a STALE_BRANCHES $branch
            end
        end

        set -l ALL_BRANCH_COUNT (count $ALL_BRANCHES)
        set -l STALE_BRANCH_COUNT (count $STALE_BRANCHES)
        echo
        echo "Found $ALL_BRANCH_COUNT total branches; $STALE_BRANCH_COUNT stale."
        echo "The following branches have had no commits in the past 6 months and will be removed:"
        for stale in $STALE_BRANCHES
            echo $stale
        end

        read --local --prompt-str "Continue (y/N)? " REPLY
        if test "$REPLY" = "y"
            for branch in $STALE_BRANCHES
                set -l REMOTE_BRANCH (echo $branch | sed 's/ *origin\///')
                if test $DRY_RUN
                    echo "Would delete remote branch: '$REMOTE_BRANCH'"
                else
                    echo "Deleting remote branch: '$REMOTE_BRANCH'"
                    git push --quiet origin --delete $REMOTE_BRANCH
                end
            end
        end
    end

    echo "Done!"
end
