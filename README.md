**Update 2014-07-22: Since Adobe won’t fix [the bug](https://bugbase.adobe.com/index.cfm?event=bug&id=3626740) I reported and unfortunately also [dropped FLV format](http://www.patrickwall.com/2014/06/18/adobe-ditch-flv-support-in-creative-cloud-2014/) last month, I won’t support this extension anymore.**

Starling-Video
====================

A Video is a Quad with a texture mapped onto it.
The Video class is more or less a Starling equivalent of Flash's Video class with attached NetStream. The texture is written automatically if not specified otherwise. Never the less you can use other DisplayObjects for rendering as well and or handle the drawing and uploading yourself if you want to.

Note: There are no controls for starting/stopping the video source in this class. This has to be done by controlling the netStream. If you start/stop the netStream, the video will recieve the Events of the netStream and handle the rest.

As "Video" inherits from "Quad", you can give it a color. For each pixel, the resulting color will be the result of the multiplication of the color of the texture with the color of the quad. That way, you can easily tint textures with a certain color. Furthermore flipping is simply done by adjusting the vertexData.

Uploading textures to the GPU is very expensive. This may be no problem on desktop computers but it is a big problem on most mobile devices. Therefore it is very important to chose the right resolution and texture size, as well as the method for drawing and uploading. If you use Flash 11.8 / AIR 3.8 (-swf-version=21) RectangleTextures are supported if necessary. Versions below will always fall back to Textue, so make sure to use the cropping rect parameter to avoid the upload of unused bytes.

Read more about performance of POT/NPOT Textures here:

http://www.flintfabrik.de/blog/camera-performance-with-stage3d

http://www.flintfabrik.de/blog/webcam-performance-with-stage3d-part-ii-rectangletextures-in-air-3-8-beta

http://www.flintfabrik.de/blog/webcam-performance-with-stage3d-part-iii-rectangletextures-in-air-3-8-beta-mobile

LIVE DEMO
=========
Some info, example code and live demo on my blog:
http://www.flintfabrik.de/blog/starling-video-extension

live chat (demo with filters for real time postprocessing): www.flintfabrik.de/pgs/starlingVideoChat/
