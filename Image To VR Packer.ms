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
		group "Name" (
			edittext edtName "" height: 24
		)		
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
			button btnCreateMiniMapPlane "Create Mini Map Plane & Camera  " width: 180 height: 30
		)
		
		group "Settings" (
			label lblInitalView "Initial View: " align: #left
			dropdownlist ddlInitialView ""
			checkbox cbxExportSelected "Export selected only"
			checkbox cbxRemoveMaterialsAndUVW "Clean Materials and UVW" checked: true
			spinner spnCubeMapsQuality "Cube Maps quality: " range: [30, 95, 65] type: #integer fieldWidth: 70 align: #left
		)
		
		button btnExport "Export" height: 40 width: 270
		
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
			
		fn getMiniMap get: #filename = (
			p = $MiniMap_Plane
			if(p == undefined) do return undefined
			if(p.material == undefined) do return undefined
			if(p.material.diffuseMap == undefined) do return undefined
			f = p.material.diffuseMap.filename			
			if(f == undefined or not doesFileExist f) do return undefined
						
			case get of (
				#object: return p
				#bitmap: p.material.diffuseMap.bitmap
				default: return f	
			)			
		)
		
		fn updateList cams: #() = (
			out = #()
			for k in 1 to cams.count where classOf cams[k] != Targetobject do (
				c = cams[k]
				n = k as string							
				p = getProp c
				
				if(c.name == "MiniMap_Camera") do (															
					continue
				)
				
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
			
			minimapCamera = $MiniMap_Camera
			if(minimapCamera != undefined) do (
				n = (out.count + 1) as string
				cname = minimapCamera.name
				
				f = getMiniMap get: #filename
				if(f != undefined) do (
					file = filenameFromPath f 
					jj = n + ". " + cname + " (" + file + ")"		
					append out jj
					append imagesList f
				)
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
				
		fn openCubeMap = (					
			i = lbxCameras.selection 
			if(i == 0) do return messageBox "Please select camera from list!" title: "Error!"
		
			c = camerasList[i]
			
			if(c.name == "MiniMap_Camera") do (
				btnCreateMiniMapPlane.pressed()
				return false
			)
			
			f = getOpenFileName caption:"Choose Image" types:"JPG (*.jpg)|*.jpg"
			if(f == undefined) do return false
		
			b = openBitMap f
			a = b.width / b.height
		
			if(a != 6) do return messageBox "CubeMap must have aspect ratio 6:1 !" title: "Error!"
					
			setProp c f

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
		
		fn exportMiniMap path: "" = (
			f = getMiniMap get: #filename
			
			copyFile (f) (path + "minimap.jpg")
		)
		
		fn exportCubeMaps path: "" = (		
			cams = cameras as array			
			
			for i in 1 to cams.count do (												
				n = cams[i].name
				filename = getProp cams[i]
				d = path + n + @"\"
				
				if(filename == undefined or not doesFileExist filename) do continue
				
				makeDir d
								
				b = openBitmap filename
				w = b.width / 6
				h = b.height
				
				tmp = bitmap w h
				
				names = #()
				
				for i in 1 to 6 do
				(
					p = (w * i) - w

					pasteBitmap b tmp (box2 p 0 w h) [0, 0]
					nn = 	n + "_" + i as string + ".jpg"
					tmp.filename = d + nn
					save tmp					

					append names nn
				)
				
				cubeMapsOptimize path: d names: names
			)
		)
		
		on btnCreateMiniMapPlane pressed do (
			
			o = $MiniMap_Plane
			
			if(o != undefined) do (
				q = queryBox "MiniMap Plane already exist!\nDo you want to continue?" title: "Confirm?"
				if(not q) do return false											
			)
			
			f = getOpenFileName  caption:"Browse" types:"JPG(*.jpg)|*.jpg"
			if(f == undefined) do return false
			
			oldPos = [0,0,0]
			oldScale = [1, 1, 1]
			oldRotation = (quat 0 0 0 1)
			
			if(o != undefined) do (
				oldPos = o.pos
				oldScale = o.scale
				oldRotation = o.rotation
				try(delete o) catch()
			)
			
			if(f.count == 0 or f == "") do return messageBox "Please select Mini Map image!" title: "Error!"
				
			nn = "MiniMap_Plane"
			
			b = Bitmaptexture()	
			b.name = nn
			b.filename = f
			
			m = Standardmaterial()
			m.name = nn
			m.opacity = 60
			m.diffuseMap = b
			
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
			
			
			-- Create camera
			
			f = getMiniMap get: #filename
			b = getMiniMap get: #bitmap
			o = getMiniMap get: #object
			
			if(f == undefined) do return messageBox "Please create MiniMap Plane first!" title: "Error!"			
			
			cc = $MiniMap_Camera
			if(cc != undefined) do try(delete cc) catch()

			nn = "MiniMap_Camera"
			
			c = Freecamera fov:45 name: nn
			c.pos = o.pos
			
			d = o.max - o.min
			d = #(d[1], d[2], d[3])
			l = amax d
			c.pos.z = c.pos.z + l
			viewport.setCamera c
			
			select c
			max zoomext sel
			displaySafeFrames = true
			
			if(b != undefined) do (
				renderWidth = b.width
				renderHeight = b.height
			)
			
			c.parent = o
			setTransformLockFlags o #{4, 5}
			
			btnUpdateList.pressed()
			
			m = "Now move and scale the plane, so that the picture on the plane completely falls with your geometry."
			messageBox m title: "Success!" beep: false
		)
		
		on edtName changed  v do (			
			bad = #("\n", "\t", "\"", ":", "\\", "&", "^", "%", "'", "$", "#", "@", "!", "?", "*")
			s = edtName.text
			for i in bad do s = substituteString s i ""
				
			edtName.text = s
		)
		
		on btnPreviewBrowse pressed do (
			f = getOpenFileName  caption:"Browse" types:"JPG(*.jpg)|*.jpg"
			if(f == undefined) do return false
			
			edtPreview.text = f			
		)
		
		on btnMiniMapBrowse pressed do (
			f = getOpenFileName  caption:"Browse" types:"JPG(*.jpg)|*.jpg"
			if(f == undefined) do return false
			
			edtMiniMap.text = f			
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
			imagesList = #()
			camerasList = getCameraList()
			--for i in 1 to camerasList.count do append imagesList undefined
			
			lbxCameras.items = updateList cams: camerasList
			ddlInitialView.items = lbxCameras.items
		)
		
		on ddlInitialView selected v do (
			i = ddlInitialView.selection 
			if(i == 0) do return false			
			c = camerasList[i]
			if(c == undefined) do return false
			
			if(c.name == "MiniMap_Camera") do (
				if(ddlInitialView.items.count > 1) do (
					ddlInitialView.selection = 1
				)
				return messageBox "You can't select MiniMap camera!" title: "Error!"
			)
		)
		
		on btnExport pressed do (
			
			updateList cams: cameras
						
			if(maxFileName == "") do return messageBox "Please save scene first!" title: "Warning!"	
			if(edtName.text.count < 2) do return messageBox "Please enter correct project name!" title: "Warning!"	
			if(not doesFileExist edtPreview.text) do return messageBox "Please select preview!" title: "Warning!"	
			if(not isCubeMapsSelected()) do return messageBox "Please bind cubemaps for all cameras!" title: "Warning!"
				
			minimapObject = getMiniMap get: #object	
			minimapFile = getMiniMap get: #filename	
			minimapBitmap = getMiniMap get: #bitmap	
			minimapCamera = $MiniMap_Camera
					
				
			if(minimapCamera != undefined) do (
				if(minimapObject == undefined) do return messageBox "Can't find MiniMap plane!" title: "Warning!"
				if(minimapFile == undefined) do return messageBox "Can't find MiniMap file!" title: "Warning!"
			)
			
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
			
			if(minimapFile != undefined) do exportMiniMap path: tmpZip
				
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
				
			-- For all scene
			for i in objects do (
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
			
			progressUpdate 60.0
				
			tmrDetectDialog.active = true
			
			deleteFile index
			exportFile index classes: VRBL_Export
			
			tmrDetectDialog.active = false
			
			exportCubeMaps path: tmpZip
			exportPreview path: tmpZip
									
			progressUpdate 90.0
			
			-- Write json
			json.put "name" (edtName.text)
			json.put "initialView" (getInitalView())
			json.put "sceneUnits" (getUnits())
			json.put "sceneScale" (units.SystemScale)			
			json.put "skybox" "beach"
			json.put "map" "false"
			json.put "showOrbitView" "true"
			json.put "viewpoints" (getViewpoints())
			json.put "preview" "index.jpg"
				
			if(minimapFile != undefined and minimapCamera != undefined and minimapCamera != undefined) do (
				json.put "minimap" "true"
				json.put "minimapFile" "minimap.jpg"
				json.put "minimapWidth" (minimapBitmap.width as string)
				json.put "minimapHeight" (minimapBitmap.height as string)
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
