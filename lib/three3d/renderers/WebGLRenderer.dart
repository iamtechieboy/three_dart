part of three_renderers;

class WebGLRenderer {
  late Map<String, dynamic> parameters;

  late var domElement;

  bool alpha = false;
  bool depth = true;
  bool stencil = true;
  bool antialias = false;
  bool premultipliedAlpha = true;
  bool preserveDrawingBuffer = false;
  String powerPreference = "default";
  bool failIfMajorPerformanceCaveat = false;

  late WebGLRenderList? currentRenderList;
  late WebGLRenderState? currentRenderState;

  // render() can be called from within a callback triggered by another render.
  // We track this so that the nested render call gets its state isolated from the parent render call.

  List<WebGLRenderState> renderStateStack = [];

  // Debug configuration container
  Map<String, dynamic> debug = {
    /**
		 * Enables error checking and reporting when shader programs are being compiled
		 * @type {boolean}
		 */
    "checkShaderErrors": true
  };

  // clearing

  bool autoClear = true;
  bool autoClearColor = true;
  bool autoClearDepth = true;
  bool autoClearStencil = true;

  // scene graph
  bool sortObjects = true;

  // user-defined clipping

  List<Plane> clippingPlanes = [];
  bool localClippingEnabled = false;

  // physically based shading

  double gammaFactor = 2.0; // for backwards compatibility
  int outputEncoding = LinearEncoding;

  // physical lights

  bool physicallyCorrectLights = false;

  // tone mapping

  int toneMapping = NoToneMapping;
  double toneMappingExposure = 1.0;

  // morphs

  int maxMorphTargets = 8;
  int maxMorphNormals = 4;

  late num width;
  late num height;

  late Vector4 _viewport;
  late Vector4 _scissor;

  // internal properties

  bool _isContextLost = false;

  // internal state cache

  var _framebuffer = null;

  int _currentActiveCubeFace = 0;
  int _currentActiveMipmapLevel = 0;
  RenderTarget? _currentRenderTarget;
  var _currentFramebuffer = null;
  int currentMaterialId = -1;

  var currentCamera = null;

  var _currentViewport = Vector4.init();
  var _currentScissor = Vector4.init();
  var _currentScissorTest = null;

  //

  double _pixelRatio = 1;
  Function? _opaqueSort = null;
  Function? _transparentSort = null;

  var _scissorTest = false;

  // frustum

  var _frustum = new Frustum(null, null, null, null, null, null);

  // clipping

  bool _clippingEnabled = false;
  bool _localClippingEnabled = false;

  // camera matrices cache

  var projScreenMatrix = new Matrix4();

  var _vector3 = Vector3.init();

  var _emptyScene = Scene();

  getTargetPixelRatio() {
    // return _currentRenderTarget == null ? _pixelRatio : 1;
    return 1;
  }

  // initialize

  late dynamic _gl;

  late WebGLExtensions extensions;
  late WebGLCapabilities capabilities;
  late WebGLState state;
  late WebGLInfo info;
  late WebGLProperties properties;
  late WebGLTextures textures;
  late WebGLCubeMaps cubemaps;
  late WebGLAttributes attributes;
  late WebGLGeometries geometries;
  late WebGLObjects objects;
  late WebGLPrograms programCache;
  late WebGLMaterials materials;
  late WebGLRenderLists renderLists;
  late WebGLRenderStates renderStates;
  late WebGLClipping clipping;

  late WebGLBackground background;
  late WebGLMorphtargets morphtargets;
  late BaseWebGLBufferRenderer bufferRenderer;
  late WebGLIndexedBufferRenderer indexedBufferRenderer;

  late WebGLUtils utils;

  late WebGLBindingStates bindingStates;

  // WebXRManager xr;

  late WebGLShadowMap shadowMap;

  WebGLRenderer(Map<String, dynamic>? parameters) {
    this.parameters = parameters ?? Map<String, dynamic>();

    width = this.parameters["width"];
    height = this.parameters["height"];

    alpha = this.parameters["alpha"] ?? false;
    depth = this.parameters["depth"] ?? true;
    stencil = this.parameters["stencil"] ?? true;
    antialias = this.parameters["antialias"] ?? false;
    premultipliedAlpha = this.parameters["premultipliedAlpha"] ?? true;
    preserveDrawingBuffer = this.parameters["preserveDrawingBuffer"] ?? false;
    powerPreference = this.parameters["powerPreference"] ?? "default";

    failIfMajorPerformanceCaveat =
        this.parameters["failIfMajorPerformanceCaveat"] ?? false;

    _viewport = Vector4(0, 0, width, height);
    _scissor = Vector4(0, 0, width, height);

    _gl = this.parameters["gl"];

    if (this.parameters["canvas"] != null) {
      this.domElement = this.parameters["canvas"];
    }
    
    print(" initGLContext ..... ");

    initGLContext();
  }

  initGLContext() {
    extensions = WebGLExtensions(_gl);
    capabilities = WebGLCapabilities(_gl, extensions, parameters);

    print("1 initGLContext ..... ");

    if (capabilities.isWebGL2 == false) {
      extensions.get('WEBGL_depth_texture');
      extensions.get('OES_texture_float');
      extensions.get('OES_texture_half_float');
      extensions.get('OES_texture_half_float_linear');
      extensions.get('OES_standard_derivatives');
      extensions.get('OES_element_index_uint');
      extensions.get('OES_vertex_array_object');
      extensions.get('ANGLE_instanced_arrays');
    }

    extensions.get('OES_texture_float_linear');

    print("2 initGLContext ..... ");

    utils = WebGLUtils(_gl, extensions, capabilities);

    state = WebGLState(_gl, extensions, capabilities);


    state.scissor(
        _currentScissor.copy(_scissor).multiplyScalar(_pixelRatio).floor());
    state.viewport(
        _currentViewport.copy(_viewport).multiplyScalar(_pixelRatio).floor());


    info = WebGLInfo(_gl);
    properties = WebGLProperties();
    textures = WebGLTextures(
        _gl, extensions, state, properties, capabilities, utils, info);

    cubemaps = WebGLCubeMaps(this);
    attributes = WebGLAttributes(_gl, capabilities);
    bindingStates =
        WebGLBindingStates(_gl, extensions, attributes, capabilities);
    geometries = WebGLGeometries(_gl, attributes, info, bindingStates);
    objects = WebGLObjects(_gl, geometries, attributes, info);
    morphtargets = WebGLMorphtargets(_gl);
    clipping = WebGLClipping(properties);
    programCache = WebGLPrograms(
        this, cubemaps, extensions, capabilities, bindingStates, clipping);
    materials = WebGLMaterials(properties);
    renderLists = WebGLRenderLists(properties);
    renderStates = WebGLRenderStates(extensions, capabilities);
    background =
        WebGLBackground(this, cubemaps, state, objects, premultipliedAlpha);

    bufferRenderer = WebGLBufferRenderer(_gl, extensions, info, capabilities);
    indexedBufferRenderer =
        WebGLIndexedBufferRenderer(_gl, extensions, info, capabilities);

    info.programs = programCache.programs;

    // xr

    // xr = WebXRManager( this, _gl );

    // shadow map

    shadowMap = WebGLShadowMap(this, objects, capabilities.maxTextureSize);

    print("3 initGLContext ..... ");
  }

  // API

  dynamic getContext() {
    return _gl;
  }

  getContextAttributes() {
    return _gl.getContextAttributes();
  }

  forceContextLoss() {
    var extension = extensions.get('WEBGL_lose_context');
    if (extension) extension.loseContext();
  }

  forceContextRestore() {
    var extension = extensions.get('WEBGL_lose_context');
    if (extension) extension.restoreContext();
  }

  getPixelRatio() {
    return _pixelRatio;
  }

  setPixelRatio(value) {
    if (value == null) return;

    _pixelRatio = value;

    this.setSize(width, height, false);
  }

  getSize(target) {
    if (target == null) {
      print('WebGLRenderer: .getsize() now requires a Vector2 as an argument');
      target = Vector2(0, 0);
    }

    return target.set(width, height);
  }

  setSize(width, height, updateStyle) {
    // if ( xr.isPresenting ) {

    // 	print( 'THREE.WebGLRenderer: Can\'t change size while VR device is presenting.' );
    // 	return;

    // }

    this.width = width;
    this.height = height;

    // print(" WebGLRenderer setSize ......... ");

    // _canvas.width = Math.floor( width * _pixelRatio );
    // _canvas.height = Math.floor( height * _pixelRatio );

    // if ( updateStyle != false ) {

    // 	_canvas.style.width = width + 'px';
    // 	_canvas.style.height = height + 'px';

    // }

    this.setViewport(0, 0, width, height);
  }

  getDrawingBufferSize(target) {
    if (target == null) {
      print(
          'WebGLRenderer: .getdrawingBufferSize() now requires a Vector2 as an argument');

      target = new Vector2(0, 0);
    }

    return target.set(width * _pixelRatio, height * _pixelRatio).floor();
  }

  setDrawingBufferSize(width, height, pixelRatio) {
    this.width = width;
    this.height = height;

    _pixelRatio = pixelRatio;

    print(" WebGLRenderer setDrawingBufferSize ");

    // _canvas.width = Math.floor( width * pixelRatio );
    // _canvas.height = Math.floor( height * pixelRatio );

    this.setViewport(0, 0, width, height);
  }

  getCurrentViewport(target) {
    if (target == null) {
      print(
          'WebGLRenderer: .getCurrentViewport() now requires a Vector4 as an argument');

      target = new Vector4.init();
    }

    return target.copy(_currentViewport);
  }

  getViewport(Vector4 target) {
    return target.copy(_viewport);
  }

  setViewport(num x, num y, num width, num height) {
    _viewport.set(x, y, width, height);
    state.viewport(
        _currentViewport.copy(_viewport).multiplyScalar(_pixelRatio).floor());
  }

  getScissor(target) {
    return target.copy(_scissor);
  }

  setScissor(x, y, width, height) {
    if (x.isVector4) {
      _scissor.set(x.x, x.y, x.z, x.w);
    } else {
      _scissor.set(x, y, width, height);
    }

    state.scissor(
        _currentScissor.copy(_scissor).multiplyScalar(_pixelRatio).floor());
  }

  getScissorTest() {
    return _scissorTest;
  }

  setScissorTest(boolean) {
    state.setScissorTest(_scissorTest = boolean);
  }

  setOpaqueSort(method) {
    _opaqueSort = method;
  }

  setTransparentSort(method) {
    _transparentSort = method;
  }

  // Clearing

  getClearColor(target) {
    if (target == null) {
      print(
          'WebGLRenderer: .getClearColor() now requires a Color as an argument');

      target = new Color(0, 0, 0);
    }

    return target.copy(background.getClearColor());
  }

  setClearColor(Color color, {num alpha = 1.0}) {
    background.setClearColor(color, alpha: alpha);
  }

  getClearAlpha() {
    return background.getClearAlpha();
  }

  setClearAlpha() {
    print(" WebGLRenderer setClearAlpha TODO need fix");

    // background.setClearAlpha.apply( background, arguments );
  }

  clear(color, depth, stencil) {
    int bits = 0;

    if (color == null || color) bits |= _gl.COLOR_BUFFER_BIT;
    if (depth == null || depth) bits |= _gl.DEPTH_BUFFER_BIT;
    if (stencil == null || stencil) bits |= _gl.STENCIL_BUFFER_BIT;

    _gl.clear(bits);
  }

  clearColor() {
    this.clear(true, false, false);
  }

  clearDepth() {
    this.clear(false, true, false);
  }

  clearStencil() {
    this.clear(false, false, true);
  }

  //

  dispose() {
    renderLists.dispose();
    renderStates.dispose();
    properties.dispose();
    cubemaps.dispose();
    objects.dispose();
    bindingStates.dispose();

    // xr.dispose();

    // animation.stop();
  }

  // Events

  onMaterialDispose(event) {
    var material = event.target;

    material.removeEventListener('dispose', onMaterialDispose);

    deallocateMaterial(material);
  }

  // Buffer deallocation

  deallocateMaterial(material) {
    releaseMaterialProgramReference(material);

    properties.remove(material);
  }

  releaseMaterialProgramReference(material) {
    var programInfo = properties.get(material)["program"];

    if (programInfo != null) {
      programCache.releaseProgram(programInfo);
    }
  }

  // Buffer rendering

  renderObjectImmediate(object, program) {
    object.render((object) {
      this.renderBufferImmediate(object, program);
    });
  }

  renderBufferImmediate(object, program) {
    bindingStates.initAttributes();

    var buffers = properties.get(object);

    if (object.hasPositions && buffers["position"] == null)
      buffers["position"] = _gl.createBuffer();
    if (object.hasNormals && buffers["normal"] == null)
      buffers["normal"] = _gl.createBuffer();
    if (object.hasUvs && buffers["uv"]) buffers["uv"] = _gl.createBuffer();
    if (object.hasColors && buffers["color"] == null)
      buffers["color"] = _gl.createBuffer();

    var programAttributes = program.getAttributes();

    if (object.hasPositions) {
      _gl.bindBuffer(_gl.ARRAY_BUFFER, buffers["position"]);
      _gl.bufferData(_gl.ARRAY_BUFFER, object.positionArray, _gl.DYNAMIC_DRAW);

      bindingStates.enableAttribute(programAttributes.position);
      _gl.vertexAttribPointer(
          programAttributes.position, 3, _gl.FLOAT, false, 0, 0);
    }

    if (object.hasNormals) {
      _gl.bindBuffer(_gl.ARRAY_BUFFER, buffers["normal"]);
      _gl.bufferData(_gl.ARRAY_BUFFER, object.normalArray, _gl.DYNAMIC_DRAW);

      bindingStates.enableAttribute(programAttributes.normal);
      _gl.vertexAttribPointer(
          programAttributes.normal, 3, _gl.FLOAT, false, 0, 0);
    }

    if (object.hasUvs) {
      _gl.bindBuffer(_gl.ARRAY_BUFFER, buffers["uv"]);
      _gl.bufferData(_gl.ARRAY_BUFFER, object.uvArray, _gl.DYNAMIC_DRAW);

      bindingStates.enableAttribute(programAttributes.uv);
      _gl.vertexAttribPointer(programAttributes.uv, 2, _gl.FLOAT, false, 0, 0);
    }

    if (object.hasColors) {
      _gl.bindBuffer(_gl.ARRAY_BUFFER, buffers["color"]);
      _gl.bufferData(_gl.ARRAY_BUFFER, object.colorArray, _gl.DYNAMIC_DRAW);

      bindingStates.enableAttribute(programAttributes.color);
      _gl.vertexAttribPointer(
          programAttributes.color, 3, _gl.FLOAT, false, 0, 0);
    }

    bindingStates.disableUnusedAttributes();

    _gl.drawArrays(_gl.TRIANGLES, 0, object.count);

    object.count = 0;
  }

  renderBufferDirect(Camera camera, dynamic? scene, geometry, Material material,
      Object3D object, group) {
    
    // renderBufferDirect second parameter used to be fog (could be null)
    if (scene == null) scene =  _emptyScene; 

    var frontFaceCW = (object.isMesh && object.matrixWorld.determinant() < 0);


    print("WebGLRenderer.renderBufferDirect object: ${object.type} ${object.id} material: ${material.type} ${material.id} geometry: ${geometry.type} ${geometry.id} object.isMesh: ${object.isMesh} frontFaceCW: ${frontFaceCW} ");

   
    WebGLProgram program = setProgram(camera, scene, material, object);




    state.setMaterial(material, frontFaceCW);


    var index = geometry.index;

    BufferAttribute? position = geometry.attributes["position"];

 
    if (index == null) {
      if (position == null || position.count == 0) return;
    } else if (index.count == 0) {
      return;
    }

    //

    var rangeFactor = 1;

    if (material.wireframe == true) {
      index = geometries.getWireframeAttribute(geometry);
      rangeFactor = 2;
    }

    if (material.morphTargets || material.morphNormals) {
      morphtargets.update(object, geometry, material, program);
    }

    bindingStates.setup(object, material, program, geometry, index);

    Map<String, dynamic> attribute;
    var renderer = bufferRenderer;

    if (index != null) {
      attribute = attributes.get(index);

      renderer = indexedBufferRenderer;
      renderer.setIndex(attribute);
    }


    var dataCount = (index != null) ? index.count : position!.count;

    var rangeStart = geometry.drawRange["start"] * rangeFactor;
    var rangeCount = geometry.drawRange["count"] * rangeFactor;

    var groupStart = group != null ? group["start"] * rangeFactor : 0;
    var groupCount = group != null ? group["count"] * rangeFactor : double.maxFinite;

    var drawStart = Math.max(rangeStart, groupStart);

    var drawEnd = Math.min3(dataCount, rangeStart + rangeCount, groupStart + groupCount) - 1;

    var drawCount = Math.max(0, drawEnd - drawStart + 1);


    if (drawCount == 0) return;

    //

    if (object.isMesh) {
      if (material.wireframe == true) {
        state
            .setLineWidth(material.wireframeLinewidth! * getTargetPixelRatio());
        renderer.setMode(_gl.LINES);
      } else {
        renderer.setMode(_gl.TRIANGLES);
      }
    } else if (object.isLine) {
      var lineWidth = material.linewidth;

      if (lineWidth == null) lineWidth = 1; // Not using Line*Material

      state.setLineWidth(lineWidth * getTargetPixelRatio());

      if (object.isLineSegments) {
        renderer.setMode(_gl.LINES);
      } else if (object.isLineLoop) {
        renderer.setMode(_gl.LINE_LOOP);
      } else {
        renderer.setMode(_gl.LINE_STRIP);
      }
    } else if (object.isPoints) {
      renderer.setMode(_gl.POINTS);
    } else if (object.type == "Sprite") {
      renderer.setMode(_gl.TRIANGLES);
    }


    if (object.isInstancedMesh) {
      renderer.renderInstances(drawStart, drawCount, object.count);
    } else if (geometry.isInstancedBufferGeometry) {


      var instanceCount = Math.min(geometry.instanceCount, geometry.maxInstanceCount);

      renderer.renderInstances(drawStart, drawCount, instanceCount);
    } else {
      renderer.render(drawStart, drawCount);
    }
  }

  // Compile

  compile(scene, camera) {
    currentRenderState = renderStates.get(scene);
    currentRenderState!.init();

    scene.traverseVisible((object) {
      if (object.isLight && object.layers.test(camera.layers)) {
        currentRenderState!.pushLight(object);

        if (object.castShadow) {
          currentRenderState!.pushShadow(object);
        }
      }
    });

    currentRenderState!.setupLights();

    var compiled = WeakMap();

    scene.traverse((object) {
      var material = object.material;

      if (material) {
        if (material is List) {
          for (var i = 0; i < material.length; i++) {
            var material2 = material[i];

            if (compiled.has(material2) == false) {
              initMaterial(material2, scene, object);
              compiled.add(key: material2, value: null);
            }
          }
        } else if (compiled.has(material) == false) {
          initMaterial(material, scene, object);
          compiled.add(key: material, value: null);
        }
      }
    });
  }

  // Animation Loop

  var onAnimationFrameCallback = null;

  onAnimationFrame(time) {
    // if ( xr.isPresenting ) return;
    if (onAnimationFrameCallback) onAnimationFrameCallback(time);
  }

  // Rendering

  render(scene, Camera camera) {
    if (camera != null && camera.isCamera != true) {
      print('THREE.WebGLRenderer.render: camera is not an instance of THREE.Camera.');
      return;
    }

    if (_isContextLost == true) return;

    // reset caching for this frame

    bindingStates.resetDefaultState();
    currentMaterialId = -1;
    currentCamera = null;

    // update scene graph

    if (scene.autoUpdate == true) scene.updateMatrixWorld(false);

    // update camera matrices and frustum

    if (camera.parent == null) camera.updateMatrixWorld(false);

    // if ( xr.enabled == true && xr.isPresenting == true ) {

    // 	camera = xr.getCamera( camera );

    // }

    if (scene.isScene == true) {
      if(scene.onBeforeRender != null) {
        scene.onBeforeRender!(
          renderer: this,
          scene: scene,
          camera: camera,
          renderTarget: _currentRenderTarget
        );
      }
    }
     

    currentRenderState = renderStates.get(scene, renderCallDepth: renderStateStack.length);
    currentRenderState!.init();

    renderStateStack.add(currentRenderState!);

    projScreenMatrix.multiplyMatrices(camera.projectionMatrix, camera.matrixWorldInverse);
 
    _frustum.setFromProjectionMatrix(projScreenMatrix);

    _localClippingEnabled = this.localClippingEnabled;
    _clippingEnabled = clipping.init(this.clippingPlanes, _localClippingEnabled, camera);

  
    currentRenderList = renderLists.get(scene, camera);
    currentRenderList!.init();

    projectObject(scene, camera, 0, this.sortObjects);

    currentRenderList!.finish();

    if (this.sortObjects == true) {
      currentRenderList!.sort(_opaqueSort, _transparentSort);
    }

    //

    if (_clippingEnabled == true) clipping.beginShadows();

    var shadowsArray = currentRenderState!.state.shadowsArray;

    shadowMap.render(shadowsArray, scene, camera);

    currentRenderState!.setupLights();
    currentRenderState!.setupLightsView(camera);

    if (_clippingEnabled == true) clipping.endShadows();

    if (this.info.autoReset == true) this.info.reset();

    background.render(currentRenderList, scene, camera, false);

    // render scene

    var opaqueObjects = currentRenderList!.opaque;
    var transparentObjects = currentRenderList!.transparent;



    if (opaqueObjects.length > 0) renderObjects(opaqueObjects, scene, camera);
    if (transparentObjects.length > 0) renderObjects(transparentObjects, scene, camera);

    if (scene.isScene == true) {
      scene.onAfterRender(renderer: this, scene: scene, camera: camera);
    }

    //

    if (_currentRenderTarget != null) {
      // Generate mipmap if we're using any kind of mipmap filtering

      textures.updateRenderTargetMipmap(_currentRenderTarget);

      // resolve multisample renderbuffers to a single-sample texture if necessary

      textures.updateMultisampleRenderTarget(_currentRenderTarget);
    }

    // Ensure depth buffer writing is enabled so it can be cleared on next render

    state.buffers["depth"].setTest(true);
    state.buffers["depth"].setMask(true);
    state.buffers["color"].setMask(true);

    state.setPolygonOffset(false, null, null);

    // _gl.finish();

    renderStateStack.removeLast();
    if (renderStateStack.length > 0) {
      currentRenderState = renderStateStack[renderStateStack.length - 1];
    } else {
      currentRenderState = null;
    }

    currentRenderList = null;
  }

  projectObject(object, camera, groupOrder, sortObjects) {
    
    if (object.visible == false) return;

    bool visible = object.layers.test(camera.layers);


    // print("projectObject object: ${object.type} ${object.id} visible: ${visible} groupOrder: ${groupOrder} sortObjects: ${sortObjects} ");

    if (visible) {
      if (object.type == "Group") {
        groupOrder = object.renderOrder;
      } else if (object.type == "LOD") {
        if (object.autoUpdate == true) object.update(camera);
      } else if (object.isLight) {
        currentRenderState!.pushLight(object);

        if (object.castShadow) {
          currentRenderState!.pushShadow(object);
        }
      } else if (object.type == "Sprite") {
        if (!object.frustumCulled || _frustum.intersectsSprite(object)) {
          if (sortObjects) {
            _vector3
                .setFromMatrixPosition(object.matrixWorld)
                .applyMatrix4(projScreenMatrix);
          }

          var geometry = objects.update(object);
          var material = object.material;

          if (material.visible) {
            currentRenderList!.push(object, geometry, material, groupOrder, _vector3.z, null);
          }
        }
      } else if (object.isImmediateRenderObject) {
        if (sortObjects) {
          _vector3
              .setFromMatrixPosition(object.matrixWorld)
              .applyMatrix4(projScreenMatrix);
        }

        currentRenderList!.push(object, null, object.material, groupOrder, _vector3.z, null);
      } else if (object.isMesh || object.isLine || object.isPoints) {
        if (object.type == "SkinnedMesh") {
          // update skeleton only once in a frame
          if (object.skeleton.frame != info.render["frame"]) {
            object.skeleton.update();
            object.skeleton.frame = info.render["frame"];
          }
        }

        if (!object.frustumCulled || _frustum.intersectsObject(object)) {

          if (sortObjects) {
            _vector3.setFromMatrixPosition(object.matrixWorld).applyMatrix4(projScreenMatrix);
          }

          // var groups2 = object.geometry.groups;
          // print(" groups2 length : ${groups2.length} ");

          var geometry = objects.update(object);

          var material = object.material;

 
          // TODO material 类型可能为 各种Material 或者各种List<Material>
          if ( material is List ) {

          	var groups = geometry.groups;

          	if(groups.length >= 1) {

              for ( var i = 0, l = groups.length; i < l; i ++ ) {

                var group = groups[ i ];
                var groupMaterial = material[ group["materialIndex"] ];

                if ( groupMaterial != null && groupMaterial.visible ) {

                  currentRenderList!.push( object, geometry, groupMaterial, groupOrder, _vector3.z, group );

                }
              }
            } else {
              material.forEach((element) {
                if(element.visible) {
                  currentRenderList!.push( object, geometry, element, groupOrder, _vector3.z, null );
                }

              });
            }

          } else if (material != null && material.visible ) {

          	currentRenderList!.push( object, geometry, material, groupOrder, _vector3.z, null );

          }

        }
      }
    }

    var children = object.children;

    for (var i = 0, l = children.length; i < l; i++) {
      projectObject(children[i], camera, groupOrder, sortObjects);
    }
  }

  renderObjects(renderList, scene, camera) {
    var overrideMaterial = scene.isScene == true ? scene.overrideMaterial : null;

    for (var i = 0, l = renderList.length; i < l; i++) {
      var renderItem = renderList[i];

      var object = renderItem.object;
      var geometry = renderItem.geometry;
      var material = overrideMaterial == null ? renderItem.material : overrideMaterial;
      var group = renderItem.group;

      if (camera.isArrayCamera) {
        var cameras = camera.cameras;

        for (var j = 0, jl = cameras.length; j < jl; j++) {
          var camera2 = cameras[j];

          if (object.layers.test(camera2.layers)) {
            state.viewport(_currentViewport.copy(camera2.viewport));

            currentRenderState!.setupLightsView(camera2);

            renderObject(object, scene, camera2, geometry, material, group);
          }
        }
      } else {
        renderObject(object, scene, camera, geometry, material, group);
      }
    }
  }

  renderObject(Object3D object, scene, Camera camera, geometry,
      Material material, group) {

    if(object.onBeforeRender != null) {
      object.onBeforeRender!(
        renderer: this,
        scene: scene,
        camera: camera,
        geometry: geometry,
        material: material,
        group: group
      );
    }

    

    object.modelViewMatrix.multiplyMatrices(camera.matrixWorldInverse, object.matrixWorld);
    object.normalMatrix.getNormalMatrix(object.modelViewMatrix);

    if (object.isImmediateRenderObject) {
      var program = setProgram(camera, scene, material, object);

      state.setMaterial(material, null);

      bindingStates.reset();

      renderObjectImmediate(object, program);
    } else {
      this.renderBufferDirect(camera, scene, geometry, material, object, group);
    }

    object.onAfterRender(
        renderer: this,
        scene: scene,
        camera: camera,
        geometry: geometry,
        material: material,
        group: group);
  }

  initMaterial(Material material, Scene scene, Object3D object) {
    if (scene.isScene != true) scene = _emptyScene; 
    // scene could be a Mesh, Line, Points, ...
   
    var materialProperties = properties.get(material);

    var lights = currentRenderState!.state.lights;
    var shadowsArray = currentRenderState!.state.shadowsArray;

    var lightsStateVersion = lights.state.version;

    var parameters = programCache.getParameters(material, lights.state, shadowsArray, scene, object);

    var programCacheKey = programCache.getProgramCacheKey(parameters);

    var program = materialProperties["program"];
    var programChange = true;


    if (program == null) {
      // new material
      material.addEventListener('dispose', onMaterialDispose);
    } else if (program.cacheKey != programCacheKey) {
      // changed glsl or parameters
      releaseMaterialProgramReference(material);
    } else if (materialProperties["lightsStateVersion"] != lightsStateVersion) {
      programChange = false;
    } else if (parameters.shaderID != null) {
      // same glsl and uniform list, envMap still needs the update here to avoid a frame-late effect

      var environment = material.isMeshStandardMaterial ? scene.environment : null;
      materialProperties["envMap"] = cubemaps.get(material.envMap ?? environment);

      return;
    } else {
      // only rebuild uniform list
      programChange = false;
    }

    if (programChange) {
      parameters.uniforms = programCache.getUniforms(material);

      if(material.onBeforeCompile != null) {
        material.onBeforeCompile!(parameters, this);
      }
      

      program = programCache.acquireProgram(parameters, programCacheKey);

      materialProperties["program"] = program;
      materialProperties["uniforms"] = parameters.uniforms;
      materialProperties["outputEncoding"] = parameters.outputEncoding;
    }

    var uniforms = materialProperties["uniforms"];

    if (!material.isShaderMaterial && !material.isRawShaderMaterial ||
        material.clipping == true) {
      materialProperties["numClippingPlanes"] = clipping.numPlanes;
      materialProperties["numIntersection"] = clipping.numIntersection;
      uniforms["clippingPlanes"] = clipping.uniform;
    }

    materialProperties["environment"] =
        material.isMeshStandardMaterial ? scene.environment : null;
    materialProperties["fog"] = scene.fog;
    materialProperties["envMap"] =
        cubemaps.get(material.envMap ?? materialProperties["environment"]);

    // store the light setup it was created for

    materialProperties["needsLights"] = materialNeedsLights(material);
    materialProperties["lightsStateVersion"] = lightsStateVersion;

    if (materialProperties["needsLights"] == true) {
      // wire up the material to this renderer's lighting state

      uniforms["ambientLightColor"]["value"] = lights.state.ambient;
      uniforms["lightProbe"]["value"] = lights.state.probe;
      uniforms["directionalLights"]["value"] = lights.state.directional;
      uniforms["directionalLightShadows"]["value"] = lights.state.directionalShadow;
      uniforms["spotLights"]["value"] = lights.state.spot;
      uniforms["spotLightShadows"]["value"] = lights.state.spotShadow;
      uniforms["rectAreaLights"]["value"] = lights.state.rectArea;
      uniforms["ltc_1"]["value"] = lights.state.rectAreaLTC1;
      uniforms["ltc_2"]["value"] = lights.state.rectAreaLTC2;
      uniforms["pointLights"]["value"] = lights.state.point;
      uniforms["pointLightShadows"]["value"] = lights.state.pointShadow;
      uniforms["hemisphereLights"]["value"] = lights.state.hemi;

      uniforms["directionalShadowMap"]["value"] = lights.state.directionalShadowMap;
      uniforms["directionalShadowMatrix"]["value"] = lights.state.directionalShadowMatrix;
      uniforms["spotShadowMap"]["value"] = lights.state.spotShadowMap;
      uniforms["spotShadowMatrix"]["value"] = lights.state.spotShadowMatrix;
      uniforms["pointShadowMap"]["value"] = lights.state.pointShadowMap;
      uniforms["pointShadowMatrix"]["value"] = lights.state.pointShadowMatrix;
      // TODO (abelnation): add area lights shadow info to uniforms

    }

    var progUniforms = materialProperties["program"].getUniforms();
    var uniformsList = WebGLUniforms.seqWithValue(progUniforms.seq, uniforms);

    // print(" init material ...............object: ${object.type} ");
    // print(uniformsList);

    materialProperties["uniformsList"] = uniformsList;
  }

  WebGLProgram setProgram(Camera camera, dynamic scene, Material material, object) {
    if (scene.isScene != true) scene = _emptyScene; 
    // scene could be a Mesh, Line, Points, ...
    

    textures.resetTextureUnits();

    var fog = scene.fog;
    var environment = material.isMeshStandardMaterial ? scene.environment : null;
    var encoding = (_currentRenderTarget == null)
        ? this.outputEncoding
        : _currentRenderTarget!.texture.encoding;
    var envMap = cubemaps.get(material.envMap ?? environment);

    var materialProperties = properties.get(material);

    var lights = currentRenderState!.state.lights;

    if (_clippingEnabled == true) {
      if (_localClippingEnabled == true || camera != currentCamera) {
        bool useCache = camera == currentCamera && material.id == currentMaterialId;

        // we might want to call this function with some ClippingGroup
        // object instead of the material, once it becomes feasible
        // (#8465, #8379)
       
        clipping.setState(material, camera, useCache);
      }
    }


    if (material.version == materialProperties["__version"]) {
      if (material.fog && materialProperties["fog"] != fog) {
        initMaterial(material, scene, object);
      } else if (materialProperties["environment"] != environment) {
        initMaterial(material, scene, object);
      } else if (materialProperties["needsLights"] &&
          (materialProperties["lightsStateVersion"] != lights.state.version)) {
        initMaterial(material, scene, object);
      } else if (materialProperties["numClippingPlanes"] != null &&
          (materialProperties["numClippingPlanes"] != clipping.numPlanes ||
              materialProperties["numIntersection"] !=
                  clipping.numIntersection)) {
        initMaterial(material, scene, object);
      } else if (materialProperties["outputEncoding"] != encoding) {
        initMaterial(material, scene, object);
      } else if (materialProperties["envMap"] != envMap) {
        initMaterial(material, scene, object);
      }
    } else {
      initMaterial(material, scene, object);
      materialProperties["__version"] = material.version;
    }

    var refreshProgram = false;
    var refreshMaterial = false;
    var refreshLights = false;

    // print(materialProperties);
    // print("-------------materialProperties------------------");

    WebGLProgram program = materialProperties["program"];
    var p_uniforms = program.getUniforms();
    var m_uniforms = materialProperties["uniforms"];

    if (state.useProgram(program.program)) {
      refreshProgram = true;
      refreshMaterial = true;
      refreshLights = true;
    }

    if (material.id != currentMaterialId) {
      currentMaterialId = material.id;

      refreshMaterial = true;
    }

    if (refreshProgram || currentCamera != camera) {
      p_uniforms.setValue(
          _gl, 'projectionMatrix', camera.projectionMatrix, null);

      if (capabilities.logarithmicDepthBuffer) {
        p_uniforms.setValue(_gl, 'logDepthBufFC',
            2.0 / (Math.log(camera.far + 1.0) / Math.LN2), null);
      }

      if (currentCamera != camera) {
        currentCamera = camera;

        // lighting uniforms depend on the camera so enforce an update
        // now, in case this material supports lights - or later, when
        // the next material that does gets activated:

        refreshMaterial = true; // set to true on material change
        refreshLights = true; // remains set until update done

      }

      // load material specific uniforms
      // (shader material also gets them for the sake of genericity)

      if (material.isShaderMaterial ||
          material.isMeshPhongMaterial ||
          material.isMeshToonMaterial ||
          material.isMeshStandardMaterial ||
          material.envMap != null) {
        var uCamPos = p_uniforms.map["cameraPosition"];

        if (uCamPos != null) {
          uCamPos.setValue(
              _gl, _vector3.setFromMatrixPosition(camera.matrixWorld));
        }
      }

      if (material.isMeshPhongMaterial ||
          material.isMeshToonMaterial ||
          material.isMeshLambertMaterial ||
          material.isMeshBasicMaterial ||
          material.isMeshStandardMaterial ||
          material.isShaderMaterial) {
        p_uniforms.setValue(
            _gl, 'isOrthographic', camera.isOrthographicCamera == true, null);
      }

      if (material.isMeshPhongMaterial ||
          material.isMeshToonMaterial ||
          material.isMeshLambertMaterial ||
          material.isMeshBasicMaterial ||
          material.isMeshStandardMaterial ||
          material.isShaderMaterial ||
          material.isShadowMaterial ||
          material.skinning) {
        p_uniforms.setValue(_gl, 'viewMatrix', camera.matrixWorldInverse, null);
      }
    }

    // skinning uniforms must be set even if material didn't change
    // auto-setting of texture unit for bone texture must go before other textures
    // otherwise textures used for skinning can take over texture units reserved for other material textures

    if (material.skinning) {
      p_uniforms.setOptional(_gl, object, 'bindMatrix');
      p_uniforms.setOptional(_gl, object, 'bindMatrixInverse');

      Skeleton? skeleton = object.skeleton;

      if (skeleton != null) {
        var bones = skeleton.bones;

        // print(" skeleton.boneMatrices ");
				// print(skeleton.boneMatrices);

        if (capabilities.floatVertexTextures) {
          if (skeleton.boneTexture == null) {
            // layout (1 matrix = 4 pixels)
            //      RGBA RGBA RGBA RGBA (=> column1, column2, column3, column4)
            //  with  8x8  pixel texture max   16 bones * 4 pixels =  (8 * 8)
            //       16x16 pixel texture max   64 bones * 4 pixels = (16 * 16)
            //       32x32 pixel texture max  256 bones * 4 pixels = (32 * 32)
            //       64x64 pixel texture max 1024 bones * 4 pixels = (64 * 64)

            var size = Math.sqrt(bones.length * 4); 
            // 4 pixels needed for 1 matrix
            
            size = MathUtils.ceilPowerOfTwo(size);
            int size2 = Math.max(size, 4).toInt();

            var boneMatrices = Float32List(size2 * size2 * 4); 
            // 4 floats per RGBA pixel
        
            setList(boneMatrices, skeleton.boneMatrices);
            
            var boneTexture = DataTexture(
                boneMatrices,
                size2,
                size2,
                RGBAFormat,
                FloatType,
                null,
                null,
                null,
                null,
                null,
                null,
                null);

      
            skeleton.boneMatrices = boneMatrices;
            skeleton.boneTexture = boneTexture;
            skeleton.boneTextureSize = size2;
          }

          p_uniforms.setValue(
              _gl, 'boneTexture', skeleton.boneTexture, textures);
          p_uniforms.setValue(
              _gl, 'boneTextureSize', skeleton.boneTextureSize, null);
        } else {
          p_uniforms.setOptional(_gl, skeleton, 'boneMatrices');
        }
      }
    }

    if (refreshMaterial ||
        materialProperties["receiveShadow"] != object.receiveShadow) {
      materialProperties["receiveShadow"] = object.receiveShadow;
      p_uniforms.setValue(_gl, 'receiveShadow', object.receiveShadow, null);
    }

    if (refreshMaterial) {
      p_uniforms.setValue(
          _gl, 'toneMappingExposure', this.toneMappingExposure, null);

      if (materialProperties["needsLights"]) {
        // the current material requires lighting info

        // note: all lighting uniforms are always set correctly
        // they simply reference the renderer's state for their
        // values
        //
        // use the current material's .needsUpdate flags to set
        // the GL state when required

        markUniformsLightsNeedsUpdate(m_uniforms, refreshLights);
      }

      // refresh uniforms common to several materials

      if (fog != null && material.fog) {
        materials.refreshFogUniforms(m_uniforms, fog);
      }

      materials.refreshMaterialUniforms(
          m_uniforms, material, _pixelRatio, height);

      WebGLUniforms.upload(
          _gl, materialProperties["uniformsList"], m_uniforms, textures, object, material);
    }

    if (material.isShaderMaterial && material.uniformsNeedUpdate == true) {
      WebGLUniforms.upload(
          _gl, materialProperties["uniformsList"], m_uniforms, textures, object, material);
      material.uniformsNeedUpdate = false;
    }

    if (material.isSpriteMaterial) {
      p_uniforms.setValue(_gl, 'center', object.center, null);
    }

    // common matrices

    p_uniforms.setValue(_gl, 'modelViewMatrix', object.modelViewMatrix, null);
    p_uniforms.setValue(_gl, 'normalMatrix', object.normalMatrix, null);
    p_uniforms.setValue(_gl, 'modelMatrix', object.matrixWorld, null);

    // print("WebGLRender.setProgram object.modelViewMatrix: ${object.modelViewMatrix.toJSON()}  ");
    // print("WebGLRender.setProgram object.normalMatrix: ${object.normalMatrix.toJSON()}  ");
    // print("WebGLRender.setProgram object.matrixWorld: ${object.matrixWorld.toJSON()}  ");

    return program;
  }

  // If uniforms are marked as clean, they don't need to be loaded to the GPU.

  markUniformsLightsNeedsUpdate(Map<String, dynamic> uniforms, value) {
    uniforms["ambientLightColor"]["needsUpdate"] = value;
    uniforms["lightProbe"]["needsUpdate"] = value;
    uniforms["directionalLights"]["needsUpdate"] = value;
    uniforms["directionalLightShadows"]["needsUpdate"] = value;
    uniforms["pointLights"]["needsUpdate"] = value;
    uniforms["pointLightShadows"]["needsUpdate"] = value;
    uniforms["spotLights"]["needsUpdate"] = value;
    uniforms["spotLightShadows"]["needsUpdate"] = value;
    uniforms["rectAreaLights"]["needsUpdate"] = value;
    uniforms["hemisphereLights"]["needsUpdate"] = value;
  }

  materialNeedsLights(material) {
    return material.isMeshLambertMaterial ||
        material.isMeshToonMaterial ||
        material.isMeshPhongMaterial ||
        material.isMeshStandardMaterial ||
        material.isShadowMaterial ||
        (material.isShaderMaterial && material.lights == true);
  }

  //
  setFramebuffer(value) {
    if (_framebuffer != value && _currentRenderTarget == null)
      _gl.bindFramebuffer(_gl.FRAMEBUFFER, value);

    _framebuffer = value;
  }

  getActiveCubeFace() {
    return _currentActiveCubeFace;
  }

  getActiveMipmapLevel() {
    return _currentActiveMipmapLevel;
  }

  getRenderList() {
    return currentRenderList;
  }

  setRenderList(renderList) {
    currentRenderList = renderList;
  }

  getRenderTarget() {
    return _currentRenderTarget;
  }

  setRenderTarget(RenderTarget? renderTarget, {int activeCubeFace = 0, int activeMipmapLevel = 0}) {

    _currentRenderTarget = renderTarget;
    _currentActiveCubeFace = activeCubeFace;
    _currentActiveMipmapLevel = activeMipmapLevel;


    if (renderTarget != null &&  properties.get(renderTarget)["__webglFramebuffer"] == null) {
      textures.setupRenderTarget(renderTarget);
    }

    var framebuffer = _framebuffer;
    var isCube = false;

    if (renderTarget != null) {
      var __webglFramebuffer = properties.get(renderTarget)["__webglFramebuffer"];

      if (renderTarget.isWebGLCubeRenderTarget) {
        framebuffer = __webglFramebuffer[activeCubeFace];
        isCube = true;
      } else if (renderTarget.isWebGLMultisampleRenderTarget) {
        framebuffer = properties.get(renderTarget)["__webglMultisampledFramebuffer"];
      } else {
        framebuffer = __webglFramebuffer;
      }

      _currentViewport.copy(renderTarget.viewport);
      _currentScissor.copy(renderTarget.scissor);
      _currentScissorTest = renderTarget.scissorTest;
    } else {
      _currentViewport.copy(_viewport).multiplyScalar(_pixelRatio).floor();
      _currentScissor.copy(_scissor).multiplyScalar(_pixelRatio).floor();
      _currentScissorTest = _scissorTest;
    }

    // print(" ${!identical(_currentFramebuffer, framebuffer)} ");

    if (_currentFramebuffer != framebuffer) {
      _gl.bindFramebuffer(_gl.FRAMEBUFFER, framebuffer);
      _currentFramebuffer = framebuffer;
    }

    state.viewport(_currentViewport);
    state.scissor(_currentScissor);
    state.setScissorTest(_currentScissorTest);

    if (isCube) {
      var textureProperties = properties.get(renderTarget!.texture);
      _gl.framebufferTexture2D(
        _gl.FRAMEBUFFER,
        _gl.COLOR_ATTACHMENT0,
        _gl.TEXTURE_CUBE_MAP_POSITIVE_X + activeCubeFace,
        textureProperties["__webglTexture"],
        activeMipmapLevel
      );
    }
  }

  readRenderTargetPixels(WebGLRenderTarget renderTarget, x, y, width, height, buffer, activeCubeFaceIndex) {
   
    var framebuffer = properties.get(renderTarget)["__webglFramebuffer"];

    if (renderTarget.isWebGLCubeRenderTarget && activeCubeFaceIndex != null) {
      framebuffer = framebuffer[activeCubeFaceIndex];
    }

    if (framebuffer != null) {
      var restore = false;

      if (framebuffer != _currentFramebuffer) {
        _gl.bindFramebuffer(_gl.FRAMEBUFFER, framebuffer);

        restore = true;
      }

      try {
        var texture = renderTarget.texture;
        var textureFormat = texture.format;
        var textureType = texture.type;

        if (textureFormat != RGBAFormat &&
            utils.convert(textureFormat) !=
                _gl.getParameter(_gl.IMPLEMENTATION_COLOR_READ_FORMAT)) {
          print(
              'THREE.WebGLRenderer.readRenderTargetPixels: renderTarget is not in RGBA or implementation defined format.');
          return;
        }

        if (textureType != UnsignedByteType &&
            utils.convert(textureType) !=
                _gl.getParameter(_gl
                    .IMPLEMENTATION_COLOR_READ_TYPE) && // IE11, Edge and Chrome Mac < 52 (#9513)
            !(textureType == FloatType &&
                (capabilities.isWebGL2 ||
                    extensions.get('OES_texture_float') ||
                    extensions.get(
                        'WEBGL_color_buffer_float'))) && // Chrome Mac >= 52 and Firefox
            !(textureType == HalfFloatType &&
                (capabilities.isWebGL2
                    ? extensions.get('EXT_color_buffer_float')
                    : extensions.get('EXT_color_buffer_half_float')))) {
          print(
              'THREE.WebGLRenderer.readRenderTargetPixels: renderTarget is not in UnsignedByteType or implementation defined type.');
          return;
        }

        if (_gl.checkFramebufferStatus(_gl.FRAMEBUFFER) ==
            _gl.FRAMEBUFFER_COMPLETE) {
          // the following if statement ensures valid read requests (no out-of-bounds pixels, see #8604)

          if ((x >= 0 && x <= (renderTarget.width - width)) &&
              (y >= 0 && y <= (renderTarget.height - height))) {
            // _gl.readPixels(x, y, width, height, utils.convert(textureFormat),
            //     utils.convert(textureType), buffer);
             _gl.readPixels(x, y, width, height, utils.convert(textureFormat), utils.convert(textureType), buffer);
          }
        } else {
          print(
              'THREE.WebGLRenderer.readRenderTargetPixels: readPixels from renderTarget failed. Framebuffer not complete.');
        }
      } finally {
        if (restore) {
          _gl.bindFramebuffer(_gl.FRAMEBUFFER, _currentFramebuffer);
        }
      }
    }
  }

  copyFramebufferToTexture(position, texture, {int level = 0}) {
    var levelScale = Math.pow(2, -level);
    var width = Math.floor(texture.image.width * levelScale);
    var height = Math.floor(texture.image.height * levelScale);
    var glFormat = utils.convert(texture.format);

    textures.setTexture2D(texture, 0);

    _gl.copyTexImage2D(_gl.TEXTURE_2D, level, glFormat, position.x, position.y,
        width, height, 0);

    state.unbindTexture();
  }

  copyTextureToTexture(position, srcTexture, dstTexture, {int level = 0}) {
    var width = srcTexture.image.width;
    var height = srcTexture.image.height;
    var glFormat = utils.convert(dstTexture.format);
    var glType = utils.convert(dstTexture.type);

    textures.setTexture2D(dstTexture, 0);

    // As another texture upload may have changed pixelStorei
    // parameters, make sure they are correct for the dstTexture
    _gl.pixelStorei(_gl.UNPACK_FLIP_Y_WEBGL, dstTexture.flipY);
    _gl.pixelStorei(
        _gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, dstTexture.premultiplyAlpha);
    _gl.pixelStorei(_gl.UNPACK_ALIGNMENT, dstTexture.unpackAlignment);

    if (srcTexture.isDataTexture) {
      _gl.texSubImage2D(_gl.TEXTURE_2D, level, position.x, position.y, width,
          height, glFormat, glType, srcTexture.image.data);
    } else {
      if (srcTexture.isCompressedTexture) {
        _gl.compressedTexSubImage2D(
            _gl.TEXTURE_2D,
            level,
            position.x,
            position.y,
            srcTexture.mipmaps[0].width,
            srcTexture.mipmaps[0].height,
            glFormat,
            srcTexture.mipmaps[0].data);
      } else {
        _gl.texSubImage2D(_gl.TEXTURE_2D, level, position.x, position.y, null,
            null, glFormat, glType, srcTexture.image);
      }
    }

    // Generate mipmaps only when copying level 0
    if (level == 0 && dstTexture.generateMipmaps)
      _gl.generateMipmap(_gl.TEXTURE_2D);

    state.unbindTexture();
  }

  initTexture(texture) {
    textures.setTexture2D(texture, 0);

    state.unbindTexture();
  }

  getRenderTargetGLTexture(renderTarget) {
    var textureProperties = properties.get( renderTarget.texture );
    return textureProperties["__webglTexture"];
  }

  resetState() {
    state.reset();
    bindingStates.reset();
  }
}