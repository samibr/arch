
#!/bin/bash


GITHUB_USERNAME="samibr"
GITHUB_TOKEN="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"
REPO="arch"

git add .
git commit -m "Update"
git push https://$GITHUB_USERNAME:$GITHUB_TOKEN@github.com/$GITHUB_USERNAME/$REPO.git
