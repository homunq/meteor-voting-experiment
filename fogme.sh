#!/bin/bash
app=${1}
echo "Bundling app"
mrt bundle app.tgz
tar -xzf app.tgz
mv bundle ../
pushd ../bundle
echo "Fixing bundle for appfog"
rm -rf server/node_modules/fibers
npm install fibers@0.6.9
echo "Updating appfog"
af update $app
echo "Cleaning up"
popd
#rm -rf ../bundle
echo "Code is in releases/$app.tgz"
mkdir -p releases
mv app.tgz releases/$app.tgz
