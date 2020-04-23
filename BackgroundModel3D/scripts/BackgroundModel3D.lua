--[[----------------------------------------------------------------------------

  Application Name:
  BackgroundModel3D
                                                                                             
  Summary:
  Detecting objects not beloning to the background. Eg. things that are moving
  or changing over time.
   
  How to Run:
  Starting this sample is possible either by running the app (F5) or
  debugging (F7+F10). Setting breakpoint on the first row inside the 'main'
  function allows debugging step-by-step after 'Engine.OnStarted' event.
  Results can be seen in the viewer on the DevicePage.
  
  More Information:
  Tutorial "Algorithms - Filtering and Arithmetic".

------------------------------------------------------------------------------]]

--Start of Global Scope---------------------------------------------------------

-- This is an line scan sensor so we select true here.
local lineScanSensor = true

-- The first two background models will never forget their past.
-- They are therefore suited for adding images in a teach phase
-- followed by a use phase where compares are called.
--
-- The RunningGaussian background model allows the model to adapt
-- to changes over time. It may be combined with a Image.PixelRegion
-- in the add call to allow adapting to changes in one area, but not
-- another.

-- Select thresholds for the algorithm

-- This version models the background using a simple average
--local meanThreshold = 1.5
--local varThreshold = nil
--local bg = Image.BackgroundModel.createAverage(lineScanSensor)

-- This version models the background using an average and a variance
--local meanThreshold = 1.0
--local varThreshold = 2.5
--local bg = Image.BackgroundModel.createGaussian(lineScanSensor)

-- Create a background model object with a learning rate
local meanThreshold = 1.0
local varThreshold = 2.5
local bg = Image.BackgroundModel.createRunningGaussian(lineScanSensor, 1/(60*10))

-- We use two viewer handles to be able to show proper overlays
local v2d = View.create()
local v3d = View.create("v3d")

-- Create a decoration object for visualizing the height data.
-- The provided data is not calibrated and the Ranger 3 sensor is 832 pixels high.
local imagedecoration = View.ImageDecoration.create()
imagedecoration:setRange(0, 832)

--End of Global Scope-----------------------------------------------------------

--Start of Function and Event Scope---------------------------------------------

-- Helper function for showing the image results
local function drawResults(refimage, objects)

  -- Clear viewers and add images
  v2d:clear()
  v3d:clear()
  local id2d = v2d:addHeightmap(refimage, imagedecoration)
  local id3d = v3d:addHeightmap(refimage, imagedecoration)

  if objects then
  
    -- Create a centroid marker
    local cross = {
      Shape.createLineSegment(Point.create(-10, -10), Point.create(10, 10)),
      Shape.createLineSegment(Point.create(-10, 10), Point.create(10, -10))}
    
    -- Create a label decorator
    local textdeco = View.TextDecoration.create()
    textdeco:setColor(255, 255, 255)
    textdeco:setSize(30)
    
    -- Visualize the bounding boxes and centroids
    local shapedeco = View.ShapeDecoration.create()
    shapedeco:setLineColor(180, 10, 10)
    shapedeco:setLineWidth(11)
    
    -- Paint the image region
    local regiondeco = View.PixelRegionDecoration.create()
    regiondeco:setColor(0, 120, 220, 150)
    
    -- Draw each object individually
    for i, region in ipairs(objects) do
    
      -- Clean up the region
      region = region:erode(11):dilate(11)
      
      -- Get the object bounds in 2D
      local bbx2D = region:getBoundingBox(refimage)
      local x, y = bbx2D:getCenterOfGravity():getXY()
      
      -- Create final indicator for pick position in 2D
      local cross2D = Shape.transform(cross, Transform.createTranslation2D(x, y))
      
      -- Get the height a quick and easy way
      local z = Image.toWorldZ(refimage, refimage:getPixel(refimage:toPixelCoordinate(Point.create(x, y)):getXY()))
      
      -- Construct 3D versions for the 3D viewer
      local bbx3D = Shape.toShape3D(bbx2D, Transform.createTranslation3D(0,0,z))
      local cross3D = Shape.toShape3D(cross, Transform.createTranslation3D(x, y, z))
      
      -- The text can be the same for 2D and 3D as long as it's above the heightmap surface
      textdeco:setPosition(x + 40, y - 10, z + 2)
      
      -- Draw 2D feedback
      v2d:addPixelRegion(region, regiondeco)
      v2d:addShape(cross2D, shapedeco)
      v2d:addShape(bbx2D, shapedeco)
      v2d:addText(tostring(i), textdeco)
      
      -- Draw 3D feedback
      v3d:addPixelRegion(region, regiondeco, nil, id3d)
      v3d:addShape(cross3D, shapedeco)
      v3d:addShape(bbx3D, shapedeco)
      v3d:addText(tostring(i), textdeco)
    end
  end
  
  -- Send data to viewers
  v2d:present()
  v3d:present()
end

-- Handle each captured image
local function callback(image)

  -- Results handles for the foreground and region to update
  local fg = nil
  local roi = nil

  -- Only do compare if the model is initialized
  if not bg:isEmpty() then
    -- Use the model to extract the foreground
    fg = bg:compare(image, "BRIGHTER", meanThreshold, varThreshold)
    
    -- Find separate blobs of certain size
    fg = fg:findConnected(10000)
    
    -- Remember foreground pixels to avoid adding it to the background
    -- Only ignore large connected regions (not noise)
    roi = Image.PixelRegion.invert(fg:getUnion():dilate(5), image)
  end

  -- Update background model with a new observation
  -- The roi is used to tell the algorithm what region is to be
  -- updated. This allows us to avoid learning foreground.
  bg:add(image, roi)
  
  -- Display a visualization
  drawResults(image, fg)

end

local function main()
  -- Use this simple function to keep the framerate
  -- we could also have used a Timer object.
  local tic = DateTime.getTimestamp()
  local function pace(hz)
    local toc = DateTime.getTimestamp()
    local sleeptime = 1000/hz - (toc-tic)
    Script.sleep(math.max(0, sleeptime))
    tic = toc
  end
  
  local images = Object.load('resources/linescan.json')
  
  -- Loop a few iterations
  for i = 1, 10 do
    -- Loop over all images
    for imageIndex = 1, #images do
      callback(images[imageIndex])
      pace(1)
    end
  end
  
end
--The following registration is part of the global scope which runs once after startup
--Registration of the 'main' function to the 'Engine.OnStarted' event
Script.register("Engine.OnStarted", main)
--End of Function and Event Scope--------------------------------------------------
