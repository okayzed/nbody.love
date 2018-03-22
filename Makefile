default: build

clean:
				rm build -fr

build:
				mkdir build
				cp main.lua build
				cp lib/ build -Rv
				find build/ -iname ".*.sw?" | xargs rm
				cd build && zip -r build.love .
				mv build/build.love .

lovejs:
			cd ../love.js/debug/ && python ../emscripten/tools/file_packager.py game.data --preload ../../3d@/ --js-output=game.js
			echo "Build game.js in ../love.js/debug"

.PHONY:clean
