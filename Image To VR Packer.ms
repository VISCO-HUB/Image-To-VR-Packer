/*  
[INFO] 

NAME = ImgToVR Packer
VERSION = 1.0.1
AUTHOR = MastaMan
DEV = VISCO
HELP = 

[1.0.0]

* First release =

[1.0.a]

+ Added: MiniMap support=

[ABOUT]


[TEST]

[SCRIPT]
*/	


	global R_IMGTOVR

	try(closeRolloutFloater F_IMGTOVR) catch()
	global F_IMGTOVR = newRolloutFloater "ImgToVR Packer" 320 700

	global camerasList = #()
	global imagesList = #()

	fn getScriptInfo s releaseInfo: "" =
	(		
		if(releaseInfo != "") do
		(
			r = getINISetting s releaseInfo
			return r
		)
		
		v = getINISetting s "INFO" "VERSION"
		a = getINISetting s "INFO" "AUTHOR"
		n = getINISetting s "INFO" "NAME"
		o = getINISetting s "ABOUT"
		c = getINISetting s "INFO" "DEV"
		h = getINISetting s "INFO" "HELP"
		
		r = for i in (getINISetting s) where i != "ABOUT" and i != "SCRIPT" and i != "COPY" collect i
		
		return #(n, a, v, o, r, c, h)
	)

	fn parseToLine m = 
	(
		if(m.count == 0) do return ""
		
		l = ""				
		for i in m do l += i + "\n"
		return l
	)
	
	struct jsonClass (
		out = #(),
		
		fn init = (
			out = #()
		),
		
		fn put param value = (
			append out #(param, value)
		),
		
		fn writeFile f t =
		(
			local tmp
			try(tmp = createFile f) catch (return false)			
			format t to:tmp
			flush tmp
			close tmp
					
			return true
		),
		
		fn convertFileToUTF8 o n  =
		(
			f = openFile o
			buffer = #()
			while (not eof f) do
			(
				szLine = readline f		
				szLine = trimRight (trimLeft szLine)		
				append buffer szLine
			)
			flush f
			close f	
			
			deleteFile o
			
			s = dotNetObject "System.IO.StreamWriter" (n) true ((dotNetClass "System.Text.Encoding").GetEncoding("UTF-8"))
			
			for l in buffer where  l.count > 0 do s.WriteLine(dotNetObject "System.String" l)			
			s.Close()		
		),
		
		fn isNumeric s = (
			s = trimRight s "1234567890."
			if(s.count > 0) do return false
			return true
		),
		
		fn q s = (
			s = s as string
			bad = #("'", "\"", "\\", "&", "^")			
			for i in bad do s = substituteString s i ""			
			
			
			if(s == "true" or s == "false") do return s
			if(isNumeric s) do return s
			return "\"" + s + "\""
		),
				
		fn v s = (
			if(classOf s == array) do (
				o = "[\n"
				for i in s do (
					o += "\t\t" + (q i)
					if(i != s[s.count]) do o += ","
					o += "\n"
				)
				o += "\t]"
				
				return o
			)
			
			return q s
		),
		
		fn write f = (
			j = "{\n"
			
				for i in out do (
					sep = ", "
					if(i == out[out.count]) do sep = ""
										
					j += "\t" + (q i[1]) + ": " + (v i[2]) + sep + "\n"
				)
			
			j += "}\n"
				
			writeFile f j
		)
	)

	struct zip (
		dirs = #(),
		files = #(),
		
		fn getRecusive d =
		(		
			c = getDirectories (d + "*")
			f = getFiles (d + "*")
			join dirs c
			join files f
			for i in c do getRecusive i
		),
		
		fn writeFile f t =
		(
			local tmp
			try(tmp = createFile f) catch (return false)			
			format t to:tmp
			flush tmp
			close tmp
					
			return true
		),
		
		fn br t =
		(
			return "\"" + t + "\""
		),
		
		fn rmDir d =
		(
			cmd = "RMDIR " + (br d) + " /S /Q"
			hiddendosCommand cmd 				
		),
		fn packFile  source: "" target: "" name: "tmpzip" del: false = 
		(	
			out = name + ".zip"
			
			curDir = sysInfo.currentDir
			sysInfo.currentDir = getFilenamePath  source
			
			maz  out (filenameFromPath source)
			
			sysInfo.currentDir = curDir 
			
			if(del == true) do deleteFile source
			return true
		),
		fn packFiles source: "" target: "" name: "tmpzip" del: false =
		(
			dirs = #()
			files = #()
			
			makeDir @"C:\temp\"
			makeDir target
			tmp = @"C:\temp\ziptmp.txt" 
			maxZip = (getDir #maxRoot) + "maxzip.exe"
				
			source = (trimRight source "\\") + "\\"
			target = (trimRight target "\\") + "\\"
			
			if(not doesFileExist source or source.count < 2) do return false
			if(not doesFileExist target or target.count < 2) do return false
			
			getRecusive source
			
			if(files.count == 0) do return false
			
			if(doesFileExist tmp) do deleteFile tmp
			t = ""		
			for i in files do t += (substituteString i source "") + "\n"
			writeFile tmp t
			
			curDir = sysInfo.currentDir
			sysInfo.currentDir = source
			out = target + name + ".zip"
			
			cmd = (br maxZip) + " " + (br out) + " @" + tmp
			
			hiddendosCommand cmd exitcode:&exitcode
			sysInfo.currentDir = curDir 
			
			if(del == true) do rmDir source
			
			if(exitcode == 0) do return true 
			return false
		)
	)
	
	fn _user32 = (
		source = ""
		source += "using System;\n"
		source += "using System.Runtime.InteropServices;\n"
		source += "class User32\n"
		source += "{\n"
		source += "	[DllImport(\"user32.dll\")]\n"
		source += "	public static extern int PostMessage(Int32 hWnd, int wMsg, int wParam, int lParam);\n"
		source += "}\n"

		csharpProvider = dotnetobject "Microsoft.CSharp.CSharpCodeProvider"
		compilerParams = dotnetobject "System.CodeDom.Compiler.CompilerParameters"

		compilerParams.GenerateInMemory = on
		compilerResults = csharpProvider.CompileAssemblyFromSource compilerParams #(source)
		compilerResults.CompiledAssembly.CreateInstance "User32"
	)
	
	fn postVRML_Settings =
	(			
		fn check b name: "" state: false = (
			if(name == "" or b[5] != name) do return false
			windows.sendMessage b[1] 241 (if(state == true) then 1 else 0) 0
		)
		
		fn sel b name: "" state: 1 = (
			if(name == "" or b[5] != name) do return false		
			(_user32()).postmessage b[1] 0x014E state 0				
		)
		
		for o in UIAccessor.GetChildWindows 0 where (t = UIAccessor.GetWindowText o) != undefined and tolower t == " vrml97 exporter" do (
			for i in (windows.getChildrenHWND o) do (
				check i name: "Normals" state: false
				check i name: "Indentation" state: false
				check i name: "Primitives" state: false
				check i name: "Color per Vertex" state: false
				check i name: "Coordinate Interpolators" state: false
				check i name: "Export Hidden Objects" state: true
				-- Set force combobox Triangles
				sel i name: "Triangles" state: 2
				sel i name: "Ngons" state: 2
				sel i name: "Quads" state: 2
				sel i name: "Visible Edges" state: 2
				-- Set force combobox 5
				sel i name: "3" state: 2
				sel i name: "4" state: 2
				sel i name: "5" state: 2
				sel i name: "6" state: 2
			)
					
			UIAccessor.PressButtonByName o "OK"
		)
		
		true		
	)
		
	fn useSettings k p w =
	(
		/*
			useSettings "key" "value/int/float/bool/bool_not" "r/w" 
		*/
		
		u = sysInfo.username
		d = getFilenamePath  (getThisScriptFilename())
		n = filenameFromPath (getThisScriptFilename())			
		settingsFile = d + @"ini\" + u + "_" + n + ".ini"
			
		v = maxVersion()
		v = 2000 + ((v[1] / 1000) - 2)
		
		t = v as string
		
		case w of
		(
			"r":
			(
				s = getINISetting settingsFile t k
				case p of
				(
					"int": return s as integer
					"float": return s as float
					"bool": if s == "true" or s.count < 1 then true else false
					"bool_not": if s == "true" then true else false
					
					default: return s
				)
			)
			default: return setINISetting settingsFile t k (p as string)
		)
	)	

	fn checkVray =
	(
		for r in RendererClass.classes where matchpattern (r as string) pattern:"*V_Ray_Adv*" do return true		
		return false	
	)
	
	fn strip s = (
		chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890-_"		
				
		s = trimLeft (trimRight s)
		s = substituteString s "  " " "	
		s = substituteString s " " "_"
		
		bad = for i in 1 to s.count where findString chars s[i] == undefined collect s[i]
		for c in bad do s = substituteString s c ""
	
		return s
	)

	rollout  R_IMGTOVR "" 
	(	
		/*group "Name" (
			edittext edtName "" height: 24
		)		*/
		group "Cameras /  Cube Maps:" (
			listbox lbxCameras "" height: 10	
			button btnUpdateList "Update List" across: 2 width: 130 height: 30
			button btnLoadImageForCamera "Bind Cube Map" width: 130 height: 30
		)
		
		group "Preview" (
			edittext edtPreview "" height: 24 readOnly: true across: 2 align: #left width: 248
			button btnPreviewBrowse "..." width: 30 height: 24 align: #right
		)
		
		group "Mini Map" (		
			button btnCreateMiniMapPlane "Create Mini Map Plane" width: 180 height: 30
		)
		
		group "Settings" (
			label lblInitalView "Initial View: " align: #left
			dropdownlist ddlInitialView ""
			checkbox cbxExportSelected "Export selected only"
			checkbox cbxRemoveMaterialsAndUVW "Clean Materials and UVW" checked: true
			--spinner spnCubeMapsQuality "Cube Maps quality: " range: [30, 95, 65] type: #integer fieldWidth: 70 align: #left
		)
		
		button btnQuickExport "Quick Export VRML" width: 270 offset: [0, 10]
		button btnExport "Export All" height: 40 width: 270 offset: [0, 10]
		
		timer tmrDetectDialog active: false interval: 25
		
		fn getCameraList = for c in (cameras as array) where classOf c != Targetobject collect c
		
		fn getProp c = (
			p = getUserProp c "cubemap"
			if(p == "") do return undefined
			return p
		)
		
		fn setProp c f = (
			setUserProp c "cubemap" f
		)
		
		fn delAllProps = (
			for i in cameras do setUserProp  i "cubemap" ""
		)
		
		fn replaceCamerasToFree = (
			o = cameras as array
			cams = for c in cameras collect #(c.pos, c.name, getUserPropBuffer c)
			try(delete o) catch()

			f = freeCamera()
			f.rotation = (eulerAngles -90 0 0) as quat

			for p in cams do (
				c = copy f
				c.pos = p[1]
				c.name = p[2]
				setUserPropBuffer c p[3]
				c.wirecolor = random white black
			)
			try(delete f) catch()
		)
				
		fn getMiniMap p get: #diffuse = (
			--p = execute ("$'" + name + "'")
			--p = getNodeByName name exact: true all: false
				
			if(p == undefined) do return undefined
			if(p.material == undefined) do return undefined
			if(p.material.diffuseMap == undefined) do return undefined
			f = p.material.diffuseMap.filename	
			if(get == #opacity) do (
				f = undefined
				if(p.material.opacityMap != undefined) do f = p.material.opacityMap.filename
			)
			
			opacityBitmap = undefined
			if(get == #opacityBitmap) do (
				if(p.material.opacityMap != undefined) do opacityBitmap = p.material.opacityMap.bitmap
			)
			
			if(f == undefined or not doesFileExist f) do return undefined
					
			
			case get of (
				#object: return p
				#diffuseBitmap: p.material.diffuseMap.bitmap
				#opacity: f
				#opacityBitmap: opacityBitmap
				default: return f					
			)			
		)
		
		fn updateList cams: #() = (
			out = #()
			for k in 1 to cams.count where classOf cams[k] != Targetobject do (
				c = cams[k]
				n = k as string							
				p = getProp c
								
				file = "Not Assigned"
				if(p != undefined) do (					
					
					if(doesFileExist p) then (
						imagesList[k] = p
						file = filenameFromPath p
					) else (
						imagesList[k] = undefined					
					)
				)
			
				cname = strip c.name
				c.name = cname
				out[k] = n + ". " + cname + " (" + file + ")"				
			)
			
			return out
		)
		
		fn isCubeMapsSelected = (
			if(imagesList.count == 0) do return false
			for i in imagesList where i == undefined do return false			
			return true
		)
		
		
		fn getInitalView = (					
			i = ddlInitialView.selection 
			c = cameras[i]
			if(c == undefined) do (
				if(c.count > 0) do return c[1].name
				return undefined
			)
			
			return c.name
		)
				
		fn bindCubeMapToCamera f i = (			
			b = openBitMap f
			a = b.width / b.height
			
			if(a != 6) do return false
			c = camerasList[i]
			
			setProp c f
			
			return true
		)
		
		fn convertPNGtoJPG2 f = (
			p = getFilenamePath f
			n = getFilenameFile f
			ext = getFilenameType f
			nn = p + n + ".jpg"
			
			b = openBitMap f	
			bb = copy b
			close b
			bb.filename = nn	
			save bb
			close bb
		)
		
		fn convertPNGtoJPG f = (	
			p = getFilenamePath f
			n = getFilenameFile f
			ext = getFilenameType f
			
			selfPath = getFileNamePath (getThisScriptFileName())				
			exe = "\"" + selfPath + "convert.exe\""
				
			curDir = sysInfo.currentDir
			sysInfo.currentDir = selfPath
			
			nn = p + n + ".jpg"
				
			cmd = exe + " -quality 100 -flatten  \"" + f + "\" \"" + nn + "\""							
			hiddenDosCommand cmd exitcode:&exitcode						
				
			sysInfo.currentDir = curDir 		
		)
		
		fn convertToDDS f = (	
			p = getFilenamePath f
			n = getFilenameFile f
			ext = getFilenameType f
			
			selfPath = getFileNamePath (getThisScriptFileName())				
			exe = "convert.exe"
				
			curDir = sysInfo.currentDir
			sysInfo.currentDir = selfPath
			
			nn = p + n + ".dds"
				
			cmd = exe + "  -format dds -define dds:mipmaps=1 -define dds:compression=dxt1  \"" + f + "\" \"" + nn + "\""							
			print cmd
			hiddenDosCommand cmd exitcode:&exitcode startpath: selfPath		
				
			sysInfo.currentDir = curDir 		
		)
		
		fn resizeCubeMap f size: 1024 quality: 99 postfix: "_low" = (
			p = getFileNamePath f
			t = getFileNameType f
			n = getFilenameFile f
			
			size = size as string + "x" + size as string
			
			selfPath = getFileNamePath (getThisScriptFileName())				
			exe = "convert.exe"
			curDir = sysInfo.currentDir
			sysInfo.currentDir = selfPath
			
			nn = p + n + postfix + t
				
			cmd = exe + " -quality " + (quality as string) + " -resize " + size + " \"" + f + "\" \"" + nn + "\""									
			hiddenDosCommand cmd exitcode:&exitcode	

			sysInfo.currentDir = curDir 
		)
		
		fn openCubeMap = (					
			i = lbxCameras.selection 
			if(i == 0) do return messageBox "Please select camera from list!" title: "Error!"
			
			f = getOpenFileName caption:"Choose Image" types:"JPG (*.jpg)|*.jpg"
			if(f == undefined) do return false
						
			n = trimRight (getFileNameFile f) "_01234567890"
			p = (getFilenamePath f) 
			files = for i in getFiles (p + n + "*.jpg") where not matchPattern i pattern: ("*" + n +"*alpha*") collect i
				
			q = false
			if(files.count > 0 and (files.count == camerasList.count)) do (
				q = queryBox ("We found " + files.count as string +  " files in this folder.\nDo you want to bind them all to cameras?") title: "Confirm?"
			)
			
			r = true
			if(not q) then (
				r = bindCubeMapToCamera f i				
			) else (
				for ii in 1 to files.count do (
					t = bindCubeMapToCamera files[ii] ii
					if(not t) do r = false
				)
			)
			
			if(not r) do return messageBox "CubeMap must have aspect ratio 6:1 !" title: "Error!"
						
			lbxCameras.items = updateList cams: camerasList
			ddlInitialView.items = lbxCameras.items
		)
		
		fn clearMapping o = (
			for nm in 1 to (meshop.getNumMaps o) do (
				if (meshop.getmapsupport o nm) do (
					try (
						meshop.freeMapChannel o nm		
						meshop.freeMapVerts o nm
						meshop.freeMapFaces o nm	
						meshop.setMapSupport o nm off
					) catch()
				)
			)
		)
		
		fn genID sec: 1 secNum: 8 = 
		(
			c = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890"
			code = ""
				
			for i in 1 to sec do 
			(
				for ii in 1 to secNum do code += c[random 1 c.count] 
				if(i != sec) do code += "-"
			)
			
			return code
		)
		
		--- !!! TO REMOVE THIS FUNC
		fn cubeMapsOptimize path: "" names: #() = (
			selfPath = getFileNamePath (getThisScriptFileName())
			jpgoptim = "\"" + selfPath + "jpegoptim.exe\""
				
			curDir = sysInfo.currentDir
			sysInfo.currentDir = path
				
			imgs = ""

			for i in names do imgs += "\"" + i + "\" "
						
			cmd = jpgoptim + " --strip-all -f -o -q --all-progressive -m" + (spnCubeMapsQuality.value as string) + "  " + imgs
				
			hiddenDosCommand cmd exitcode:&exitcode	
				
			sysInfo.currentDir = curDir 
		)
		
		
		fn getUnits = 
		(	
			u = trimLeft (units.SystemType as string) "#"
			u[1] = toUpper u[1]
			return u
		)
				
		fn getViewpoints = (
			cams = cameras as array	
			return for i in cams collect i.name
		)
		
		fn exportPreview path: "" = (
			copyFile (edtPreview.text) (path + "index.jpg")
		)
		
		fn getMiniMaps = for i in objects where (matchPattern i.name pattern: "MiniMap_Plane*") and (getMiniMap i get: #diffuse) != undefined collect i
			
		fn exportMiniMap path: "" = (			
			o = getMiniMaps()
			out1 = #()
			out2 = #()
			out3 = #()
			
			for i in o do (
				f = getMiniMap i get: #diffuse
				b = getMiniMap i get: #diffuseBitmap
				
				opacity = getMiniMap i get: #opacity
				opacityBitmap = getMiniMap i get: #opacityBitmap
				
				if(f == undefined) do continue
				t = getFilenameType f
				n = i.name + t
				copyFile (f) (path + n)
				s = ([b.width, b.height]) as string
				
				opacityName = undefined
				if(opacity != undefined) do (
					opacityName = i.name + "_alpha" + t
					copyFile (opacity) (path + opacityName)					
				)
				
				append out1 n
				append out2 s
				append out3 opacityName
			)		

			return #(out1, out2, out3)
		)
		
		fn sliceCubeMap filename dir name parts: 6 resize: -1 postfix: "_low"= (
			b = openBitmap filename
			w = b.width / parts
			h = b.height
			
			tmp = bitmap w h
			
			for i in 1 to parts do
			(
				p = (w * i) - w

				pasteBitmap b tmp (box2 p 0 w h) [0, 0]
				nn = 	name + "_" + i as string
				t = getFileNameType filename
				tmp.filename = dir + nn + t
				save tmp					

				--resizeCubeMap (tmp.filename) size: 1024 postfix: ""
				--convertToDDS (tmp.filename)
				if(resize != -1) do resizeCubeMap (tmp.filename) size: resize postfix: postfix				
			)
		)
		
		fn exportCubeMapsAlpha path: "" = (		
			cams = cameras as array		

			textures = #()
			
			for i in 1 to cams.count do (
				n = cams[i].name
				filename = getProp cams[i]
				nn = trimRight (getFileNameFile filename) "01234567890"
				nums = trimLeft (getFileNameFile filename) nn
					
				pp = getFileNamePath filename
				ee = getFileNameType filename
				
				files = getFiles(pp + nn + "*alpha*" + nums + ee)
				if(files.count == 0) do getFiles(pp + nn + nums +"*alpha*" +  ee)
								
				if(files.count != 1) do return false
				if(files[1] == undefined or not doesFileExist files[1]) do return false
				
				append textures #(files[1],  n)
			)	
			
			for i in 1 to textures.count do (												
				n = textures[i][2]
				filename = textures[i][1]
				d = path + n + @"\"
							
				makeDir d
					
				sliceCubeMap filename d (n + "_alpha") resize: 512 postfix: ""
			)	

			return true
		)
		
		fn exportCubeMaps path: "" = (		
			cams = cameras as array			
			
			for i in 1 to cams.count do (												
				n = cams[i].name
				filename = getProp cams[i]
				d = path + n + @"\"
								
				if(filename == undefined or not doesFileExist filename) do continue
								
				makeDir d
				sliceCubeMap filename d n resize: 1000
				
				/*	
				b = openBitmap filename
				w = b.width / 6
				h = b.height
				
				tmp = bitmap w h
				
				names = #()
				low = #()
				
				for i in 1 to 6 do
				(
					p = (w * i) - w

					pasteBitmap b tmp (box2 p 0 w h) [0, 0]
					nn = 	n + "_" + i as string
					t = ".jpg"
					tmp.filename = d + nn + t
					save tmp					

					resizeCubeMap (tmp.filename) size: 1000
					
					append names nn
					append low (d + nn + "_low" + t)
				)
				*/
				-- !!!!!!!!!!!!
				--cubeMapsOptimize path: d names: names
				--cubeMapsOptimize path: d names: low				
			)
		)
		
		fn detectWrongCameras = (
			w = for c in cameras where classOf c != Freecamera collect c
				
			if(w.count == 0) do return false
			
			q = queryBox "In scene found wrong format cameras!\nDo you want to replace them to \"Free\" cameras?\n\nCameras different than \"Free\" will not be exported!" title: "Confirm?"
			if(not q) do return false
			
			replaceCamerasToFree()
			
			camerasList = getCameraList()
			updateList cams: camerasList			
		)
		
		on btnCreateMiniMapPlane pressed do (			
					
			f = getOpenFileName  caption:"Browse" types:"JPG(*.jpg)|*.jpg|PNG(*.png)|*.png"
			if(f == undefined) do return false
			
			oldPos = [0,0,0]
			oldScale = [1, 1, 1]
			oldRotation = (quat 0 0 0 1)
						
			if(f.count == 0 or f == "") do return messageBox "Please select Mini Map image!" title: "Error!"
				
			nn = "MiniMap_Plane"
			nn = uniqueName nn numDigits: 3
			
			fname = getFileNameFile f
			fpath = getFileNamePath f
			fext = getFileNameType f
			
			alphaTex = undefined
			alphaTextures = getFiles(fpath + fname + "*alpha*" + fext)
			if(alphaTextures.count == 1) do alphaTex = alphaTextures[1]
			
			
			b = Bitmaptexture()	
			b.name = nn
			b.filename = f
			
			a = undefined
			if(alphaTex != undefined) do (
				a = Bitmaptexture()
				a.name = nn + "_Alpha"
				a.filename = alphaTex
			)
			
			m = Standardmaterial()
			m.name = nn
			m.opacity = 60
			m.diffuseMap = b
			m.opacityMap = a
			
			m.showInViewport = on
				
			p = plane()
			p.lengthsegs = 1
			p.widthsegs = 1
			p.name = nn
			p.material = m
						
			a = ((b.bitmap.width as float) / (b.bitmap.height as float)) 
			
			h = (10.0 / a) as string
			
			p.width = units.decodeValue "10m" 
			p.length = units.decodeValue (h + "m")
			p.showFrozenInGray = off
			
			p.pos = oldPos
			p.scale = oldScale
			p.rotation = oldRotation
			
			select p
			max zoomext sel
				
			m = "Please scale and align your Mini Map to match the walls..."
			messageBox m title: "Success!" beep: false
		)
		
		/*on edtName changed  v do (			
			bad = #("\n", "\t", "\"", ":", "\\", "&", "^", "%", "'", "$", "#", "@", "!", "?", "*")
			s = edtName.text
			for i in bad do s = substituteString s i ""
				
			edtName.text = s
		)*/
		
		on btnPreviewBrowse pressed do (
			f = getOpenFileName  caption:"Browse" types:"JPG(*.jpg)|*.jpg"
			if(f == undefined) do return false
			
			edtPreview.text = f			
		)
					
		on tmrDetectDialog tick do (
			postVRML_Settings()
		)
		
		on btnUpdateList pressed do (
			camerasList = getCameraList()
			lbxCameras.items = updateList cams: camerasList
			ddlInitialView.items = lbxCameras.items
		)
				
		on lbxCameras doubleClicked  a do (
			--openCubeMap()	
			
			i = lbxCameras.selection 
			if(i == 0) do return false		
			if(imagesList[i] == undefined) do return false
		
			shellLaunch imagesList[i] ""
		)
		
		on btnLoadImageForCamera pressed do (
			openCubeMap()
		)
			
		on R_IMGTOVR open do (
			
			err = units.SystemType != #meters
			if(err) do (
				messageBox "Please convert your scene in to system units Meters for export and try again!" title: "Warning"
				try(closeRolloutFloater F_IMGTOVR) catch()
				return false
			)
			
			imagesList = #()
			camerasList = getCameraList()
			--for i in 1 to camerasList.count do append imagesList undefined
			
			lbxCameras.items = updateList cams: camerasList
			ddlInitialView.items = lbxCameras.items
			
			detectWrongCameras()						
		)
		
		on ddlInitialView selected v do (
			i = ddlInitialView.selection 
			if(i == 0) do return false			
			c = camerasList[i]
			if(c == undefined) do return false			
		)
		
		fn exportVRML file: "" = (
			-- For all scene
			for i in objects where not (matchPattern i.name pattern: "MiniMap_Plane*") do (
				if(canConvertTo i Editable_Mesh) do (
					-- Convert to mesh
					try(convertToMesh i) catch()					
					if(isValidNode i and classOf i == Editable_Mesh) do (
						--Clean mapping and UVW
						if(cbxRemoveMaterialsAndUVW.checked) do (
							try(i.material = undefined)catch()				
							clearMapping i
						)
						
						--Remove smoothgroups
						meshop.autosmooth i i.faces 0
						update i
					)										
				)
			)	
			
			tmrDetectDialog.active = true
			
			deleteFile file
			exportFile file classes: VRBL_Export
			
			tmrDetectDialog.active = false
		)
		
		on btnQuickExport pressed do (
			index = getSaveFileName caption: "Save Archive" types: "WRL (*.wrl)|*.wrl" filename: "index.wrl"
			if(index == undefined) do return false
			
			exportVRML file: index
			
			messageBox "VRML Export Done." title: "Done!" beep: false
		)
				
		on btnExport pressed do (
			
			updateList cams: cameras
						
			if(maxFileName == "") do return messageBox "Please save scene first!" title: "Warning!"	
			--if(edtName.text.count < 2) do return messageBox "Please enter correct project name!" title: "Warning!"	
			if(not doesFileExist edtPreview.text) do return messageBox "Please select preview!" title: "Warning!"	
			if(not isCubeMapsSelected()) do return messageBox "Please bind cubemaps for all cameras!" title: "Warning!"
			
			outZip = getSaveFileName caption: "Save Archive" types: "ZIP (*.zip)|*.zip"
			if(outZip == undefined) do return false
				
			max file save	
				
			local json = jsonClass()
			json.init()
				
			gid = genID()	
			outPath = getFilenamePath outZip
			outName = getFilenameFile outZip
			outFullName = gid
				
			progressStart "Pack Scene..."	
				
			tmpZip = outPath + outFullName + @"\"
			makeDir tmpZip
			
			exportedMiniMaps = exportMiniMap path: tmpZip
				
			index = (tmpZip + "index.wrl")
			
						
			nodes = $*
			if(cbxExportSelected.checked) do nodes = $
			
			out = @"C:\temp\"
			makeDir out
			out += "_tmp_ImgToVR_Packer.max"
			originalFile = maxFilePath + maxFileName
			
			saveNodes nodes out quiet: true
			
			progressUpdate 30.0
			
			loadMaxFile out useFileUnits: true quiet: true
							
			progressUpdate 60.0
				
			exportVRML file: index
			
			exportCubeMaps path: tmpZip			
			exportPreview path: tmpZip
			
			isAlpha = exportCubeMapsAlpha path: tmpZip
									
			progressUpdate 90.0
			
			-- Write json
			--json.put "name" (edtName.text)
			json.put "initialView" (getInitalView())
			json.put "sceneUnits" (getUnits())
			json.put "sceneScale" (units.SystemScale)			
			json.put "skybox" "beach"
			json.put "map" "false"
			json.put "showOrbitView" "true"
			json.put "viewpoints" (getViewpoints())
			json.put "preview" "index.jpg"
			json.put "viewpointsAlpha" (isAlpha as string)
			
			if(exportedMiniMaps[1].count) do (
				json.put "minimap" "true"
				json.put "minimapFiles" exportedMiniMaps[1]								
				json.put "minimapRes" exportedMiniMaps[2]
				json.put "minimapAlpha" exportedMiniMaps[3]
			)
				
			json.write (tmpZip + "index.json")
			
			zipper = zip()
			zipper.packFiles source: tmpZip target: outPath name: outName del: true
				
			progressUpdate 100.0	
			
			resetMaxFile #noPrompt
			loadMaxFile originalFile useFileUnits: true quiet: true
			
			progressEnd()	
				
			q = queryBox "Model packed success!\nDo you want to open containing folder?" title: "Success!"
			if(q) do shellLaunch outPath ""	
		)
	)

	rollout R_ABOUT "About" 
	(
		label lblName "" 
		label lblVer "" 
		
		label lblAuthor "" height: 30
		label lblCopy ""  height: 30
		
		on R_ABOUT open do
		(		
			i = getScriptInfo (getThisScriptFilename())
				
			lblName.caption = i[1]
			lblAuthor.caption = i[2]
			lblVer.caption = i[3]
			lblCopy.caption = i[6]
		)
	)



	addRollout R_IMGTOVR F_IMGTOVR rolledUp:false border: false
	addRollout R_ABOUT F_IMGTOVR rolledUp:true 
