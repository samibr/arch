
#!/bin/bash


GITHUB_USERNAME="samibr"
GITHUB_TOKEN="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"
REPO="arch"

git add .
git commit -m "Update"
git push https://$GITHUB_USERNAME:$GITHUB_TOKEN@github.com/$GITHUB_USERNAME/$REPO.git

