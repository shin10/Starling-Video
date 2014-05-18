/**
 *	Copyright (c) 2013 Michael Trenkler
 *
 *	Permission is hereby granted, free of charge, to any person obtaining a copy
 *	of this software and associated documentation files (the "Software"), to deal
 *	in the Software without restriction, including without limitation the rights
 *	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 *	copies of the Software, and to permit persons to whom the Software is
 *	furnished to do so, subject to the following conditions:
 *
 *	The above copyright notice and this permission notice shall be included in
 *	all copies or substantial portions of the Software.
 *
 *	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 *	THE SOFTWARE.
 */

package de.flintfabrik.starling.display
{
	import de.flintfabrik.starling.events.VideoEvent;
	import flash.desktop.*;
	import flash.display.BitmapData;
	import flash.display3D.textures.*;
	import flash.events.*;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.media.Video;
	import flash.net.NetStream;
	import flash.system.Capabilities;
	import flash.utils.getDefinitionByName;
	import flash.utils.getQualifiedClassName;
	import flash.utils.getTimer;
	import starling.core.RenderSupport;
	import starling.core.Starling;
	import starling.display.BlendMode;
	import starling.display.Quad;
	import starling.events.Event;
	import starling.textures.ConcreteTexture;
	import starling.textures.Texture;
	import starling.textures.TextureSmoothing;
	import starling.utils.VertexData;
	
	/** Dispatched when a new frame of the video is available. */
	[Event(name="videoFrame",type="de.flintfabrik.starling.events.VideoEvent")]
	/** Dispatched after a new frame has been drawn to BitmapData. */
	[Event(name="drawComplete",type="de.flintfabrik.starling.events.VideoEvent")]
	/** Dispatched after a new frame has been uploaded from the BitmapData to texture. */
	[Event(name="uploadComplete",type="de.flintfabrik.starling.events.VideoEvent")]
	
	/** A Video is a Quad with a texture mapped onto it.
	 *
	 *  <p>The Video class is more or less a Starling equivalent of Flash's Video class with attached <em>NetStream</em>.
	 *  The texture is written automatically if not specified otherwise. Never the less you can use other DisplayObjects
	 *  for rendering as well and or handle the drawing and uploading yourself if you want to.</p>
	 *
	 *  <p><strong>Note:</strong><em>There are no controls for starting/stopping the video source in this class. This has to be done by controlling the
	 *  netStream. If you start/stop the netStream, the video will recieve the Events of the netStream and handle the rest.</em></p>
	 *
	 *  <p>As "Video" inherits from "Quad", you can give it a color. For each pixel, the resulting
	 *  color will be the result of the multiplication of the color of the texture with the color of
	 *  the quad. That way, you can easily tint textures with a certain color. Furthermore flipping is simply done by
	 *  adjusting the vertexData.</p>
	 *
	 *  <p>Uploading textures to the GPU is very expensive. This may be no problem on desktop computers
	 *  but it is a big problem on most mobile devices. Therefore it is very important to chose the right
	 *  resolution and texture size, as well as the method for drawing and uploading.
	 *  If you use Flash 11.8 / AIR 3.8 (-swf-version=21) RectangleTextures are supported if necessary. Versions below will
	 *  always fall back to Textue, so make sure to use the cropping rect parameter to avoid the upload of unused bytes.</p>
	 *
	 *  <p>Read more about performance of POT/NPOT Textures here:
	 *  <ul>
	 *  <li><a href="http://www.flintfabrik.de/blog/camera-performance-with-stage3d">Webcam Performance with Stage3D – Part I (desktop/mobile)</a></li>
	 *  <li><a href="http://www.flintfabrik.de/blog/webcam-performance-with-stage3d-part-ii-rectangletextures-in-air-3-8-beta">Webcam Performance with Stage3D – Part II RectangleTextures in AIR 3.8 Beta (desktop)</a></li>
	 *  <li><a href="http://www.flintfabrik.de/blog/webcam-performance-with-stage3d-part-iii-rectangletextures-in-air-3-8-beta-mobile">Webcam Performance with Stage3D – Part III RectangleTextures in AIR 3.8 Beta (mobile)</a></li>
	 *  </ul>
	 *  </p>
	 *
	 *  @see starling.textures.Texture
	 *  @see starling.display.Quad
	 *
	 *  @see http://www.flintfabrik.de/blog/camera-performance-with-stage3d
	 *  @author Michael Trenkler
	 */
	
	public class Video extends starling.display.Quad
	{
		private static const HEIGHT:int = 120;
		private static const WIDTH:int = 160;
		public static const STATS_PRECISION:uint = 15;
		
		private var mActive:Boolean = true;
		private var mAddedToStage:Boolean = false;
		private var mAlpha:Boolean = false;
		private var mAutoResumeAfterSeekComplete:Boolean = false;
		private var mAutoStartAfterHandledLostContext:Boolean = false;
		private var mBitmapData:BitmapData;
		private var mContextLost:Boolean = false;
		private var mCurrentFrame:int = 0;
		private var mDecodedFrames:int = 0;
		private var mDecodedFramesOffset:int = 0;
		private var mDroppedFramesOffset:int = 0;
		private var mFlipHorizontal:Boolean = false;
		private var mFlipVertical:Boolean = false;
		private var mForceRecording:Boolean = false;
		private var mFrame:Rectangle = new Rectangle();
		private var mFrameMatrix:Matrix = new Matrix();
		private var mLastFrame:int = 0;
		private var mMetaData:Object = {};
		private var mNativeApplicationClass:Class;
		private var mNewFrameAvailable:Boolean = false;
		private var mRecording:Boolean = true;
		private var mSmoothing:String = TextureSmoothing.TRILINEAR;
		private var mStartKeyframe:int = 0;
		private var mStatsDrawnFrames:uint = 0;
		private var mStatsDrawTime:Vector.<uint> = new Vector.<uint>();
		private var mStatsUploadedFrames:uint = 0;
		private var mStatsUploadTime:Vector.<uint> = new Vector.<uint>();
		private var mStream:NetStream;
		private var mStreamPlaying:Boolean = false;
		private var mTexture:starling.textures.Texture;
		private var mTextureClass:Class;
		private var mTime:uint;
		private var mVertexDataCache:VertexData;
		private var mVertexDataCacheInvalid:Boolean;
		private var mVideo:flash.media.Video = new flash.media.Video(WIDTH, HEIGHT);
		
		/** Creates a Video
		 * @param netStream
		 * The NetStream attached to the Video.
		 * @param rect
		 * A cropping rectangle. If null, the full image will be drawn.
		 * @param autoStart
		 * If true the video will be drawn to texture as soon as the Video instance is added to stage.
		 * Recording stops automatically if the Video instance is removed from stage. To prevent this
		 * behaviour use start(true) to force recording, even if the Video is not part of the display list.
		 * @param alpha
		 * Whether the bitmapData for uploading has an alpha channel.
		 */
		
		public function Video(stream:NetStream, rect:Rectangle = null, autoStart:Boolean = true, alpha:Boolean = false)
		{
			var pma:Boolean = true;
			
			mStream = stream;
			mStream.addEventListener(NetStatusEvent.NET_STATUS, netStatusHandler);
			mStream.addEventListener(AsyncErrorEvent.ASYNC_ERROR, asyncErrorHandler);
			mStream.client = {};
			mStream.client.onMetaData = netStream_onMetaData;
			mStream.client.onXMPData = netStream_onXMPMetaData;
			
			if (rect == null)
				rect = new Rectangle(0, 0, mVideo.width, mVideo.height);
			mFrame = new Rectangle(rect.x, rect.y, Math.min(mVideo.width - rect.x, rect.width), Math.min(mVideo.height - rect.y, rect.height));
			super(mFrame.width, mFrame.height, 0xffffff, pma);
			
			mRecording = autoStart;
			mAlpha = alpha;
			mBitmapData = new BitmapData(mFrame.width, mFrame.height, mAlpha, 0);
			readjustSize(mFrame);
			mVertexDataCache = new VertexData(4, pma);
			updateVertexData();
			
			addEventListener(starling.events.Event.ADDED_TO_STAGE, addedToStageHandler);
			
			// Android / iOS / Blackberry?
			if (Capabilities.playerType.match(/desktop/i))
			{
				try
				{
					mNativeApplicationClass = Class(getDefinitionByName("flash.desktop.NativeApplication"));
					if ((Capabilities.os + Capabilities.manufacturer).match(/Android|iOS|iPhone|iPad|iPod|Blackberry/i) && mNativeApplicationClass && mNativeApplicationClass.nativeApplication)
					{
						mNativeApplicationClass.nativeApplication.addEventListener(flash.events.Event.ACTIVATE, activateHandler);
						mNativeApplicationClass.nativeApplication.addEventListener(flash.events.Event.DEACTIVATE, deactivateHandler);
					}
				}
				catch (err:*)
				{
					trace(err.toString())
				}
			}
			// windows and web
			Starling.current.addEventListener(starling.events.Event.CONTEXT3D_CREATE, contextCreateHandler);
		}
		
		/**
		 * Resume on application focus for mobile devices.
		 * @param	e
		 */
		private function activateHandler(e:flash.events.Event):void
		{
			start(mAutoStartAfterHandledLostContext);
		}
		
		/**
		 * Starting the video recording if the instance is added to the stage and autoStart true.
		 * @param	e
		 */
		private function addedToStageHandler(e:starling.events.Event):void
		{
			mAddedToStage = true;
			onVideoChange();
			addEventListener(starling.events.Event.REMOVED_FROM_STAGE, removedFromStageHandler);
		}
		
		private function asyncErrorHandler(event:AsyncErrorEvent):void
		{
			trace("AsyncErrorEvent", event);
		}
		
		/**
		 * Restart after device loss.
		 * @param	e
		 */
		private function contextCreateHandler(e:starling.events.Event):void
		{
			if (Starling.current.context && Starling.current.context.driverInfo != "Disposed" && mContextLost)
			{
				mContextLost = false;
				readjustSize(mFrame);
				start(mAutoStartAfterHandledLostContext);
			}
		}
		
		/** Copies the raw vertex data to a VertexData instance.
		 *  The texture coordinates are already in the format required for rendering. */
		override public function copyVertexDataTo(targetData:VertexData, targetVertexID:int = 0):void
		{
			if (mVertexDataCacheInvalid)
			{
				mVertexDataCacheInvalid = false;
				mVertexData.copyTo(mVertexDataCache);
				mTexture.adjustVertexData(mVertexDataCache, 0, 4);
			}
			
			mVertexDataCache.copyTo(targetData, targetVertexID);
		}
		
		/**
		 * Pause on lost application focus for mobile devices.
		 * @param	e
		 */
		private function deactivateHandler(e:flash.events.Event):void
		{
			mAutoStartAfterHandledLostContext = isActive;
			pause();
		}
		
		/** Disposes all resources of the Video Object.
		 *  Detaches the NetStream, removes EventListeners, disposes textures and bitmapDatas
		 */
		override public function dispose():void
		{
			mStreamPlaying = false;
			mRecording = false;
			mVideo.removeEventListener(flash.events.Event.ENTER_FRAME, video_enterFrameHandler);
			
			removeEventListener(starling.events.Event.ADDED_TO_STAGE, addedToStageHandler);
			removeEventListener(starling.events.Event.REMOVED_FROM_STAGE, removedFromStageHandler);
			Starling.current.removeEventListener(starling.events.Event.CONTEXT3D_CREATE, contextCreateHandler);
			if (mNativeApplicationClass)
			{
				mNativeApplicationClass.nativeApplication.removeEventListener(flash.events.Event.ACTIVATE, activateHandler);
				mNativeApplicationClass.nativeApplication.removeEventListener(flash.events.Event.DEACTIVATE, deactivateHandler);
			}
			disposeVideo();
			if (mTexture)
				mTexture.dispose();
			if (texture)
				texture.dispose();
			if (mBitmapData)
				mBitmapData.dispose();
			if (parent)
				parent.removeChild(this);
			super.dispose();
		}
		
		private function disposeVideo():void
		{
			if (mVideo)
			{
				mVideo.removeEventListener(flash.events.Event.ENTER_FRAME, video_enterFrameHandler);
				mVideo.attachNetStream(null);
			}
		}
		
		/**
		 * Drawing the video image to the BitmapData.
		 * @see Video
		 */
		public function draw():void
		{
			if (!contextStatus)
				return;
			
			if (!mNewFrameAvailable)
				return;
			
			if (!mVideo)
				return;
			
			mTime = getTimer();
			
			if (mAlpha)
				mBitmapData.fillRect(mBitmapData.rect, 0);
			mBitmapData.draw(mVideo, mFrameMatrix);
			mStatsDrawTime.unshift(getTimer() - mTime);
			
			while (mStatsDrawTime.length > STATS_PRECISION)
				mStatsDrawTime.pop();
			
			mNewFrameAvailable = false;
			mLastFrame = mCurrentFrame;
			++mStatsDrawnFrames;
			dispatchEventWith(de.flintfabrik.starling.events.VideoEvent.DRAW_COMPLETE);
		}
		
		private function netStatusHandler(event:NetStatusEvent):void
		{
			
			switch (event.info.code)
			{
				
				case "NetConnection.Call.BadVersion": 
					//Packet encoded in an unidentified format.
					break;
				case "NetConnection.Call.Failed": 
					//The NetConnection.call() method was not able to invoke the server-side method or command.
					break;
				case "NetConnection.Call.Prohibited": 
					//An Action Message Format (AMF) operation is prevented for security reasons. Either the AMF URL is not in the same domain as the file containing the code calling the NetConnection.call() method, or the AMF server does not have a policy file that trusts the domain of the the file containing the code calling the NetConnection.call() method.
					break;
				case "NetConnection.Connect.AppShutdown": 
					//The server-side application is shutting down.
					break;
				case "NetConnection.Connect.Closed": 
					//The connection was closed successfully.
					mStreamPlaying = false;
					break;
				case "NetConnection.Connect.Failed": 
					//The connection attempt failed.
					break;
				case "NetConnection.Connect.IdleTimeout": 
					//Flash Media Server disconnected the client because the client was idle longer than the configured value for <MaxIdleTime>. On Flash Media Server, <AutoCloseIdleClients> is disabled by default. When enabled, the default timeout value is 3600 seconds (1 hour). For more information, see Close idle connections.
					break;
				case "NetConnection.Connect.InvalidApp": 
					//The application name specified in the call to NetConnection.connect() is invalid.
					break;
				case "NetConnection.Connect.NetworkChange": 
					//Flash Player has detected a network change, for example, a dropped wireless connection, a successful wireless connection,or a network cable loss. Use this event to check for a network interface change. Don't use this event to implement your NetConnection reconnect logic. Use "NetConnection.Connect.Closed" to implement your NetConnection reconnect logic.
					break;
				case "NetConnection.Connect.Rejected": 
					//The connection attempt did not have permission to access the application.
					break;
				case "NetConnection.Connect.Success": 
					//The connection attempt succeeded.
					break;
				case "NetGroup.Connect.Failed": 
					//The NetGroup connection attempt failed. The info.group property indicates which NetGroup failed.
					break;
				case "NetGroup.Connect.Rejected": 
					//The NetGroup is not authorized to function. The info.group property indicates which NetGroup was denied.
					break;
				case "NetGroup.Connect.Success": 
					//The NetGroup is successfully constructed and authorized to function. The info.group property indicates which NetGroup has succeeded.
					break;
				case "NetGroup.LocalCoverage.Notify": 
					//Sent when a portion of the group address space for which this node is responsible changes.
					break;
				case "NetGroup.MulticastStream.PublishNotify": 
					//Sent when a new named stream is detected in NetGroup's Group. The info.name:String property is the name of the detected stream.
					break;
				case "NetGroup.MulticastStream.UnpublishNotify": 
					//Sent when a named stream is no longer available in the Group. The info.name:String property is name of the stream which has disappeared.
					break;
				case "NetGroup.Neighbor.Connect": 
					//Sent when a neighbor connects to this node. The info.neighbor:String property is the group address of the neighbor. The info.peerID:String property is the peer ID of the neighbor.
					break;
				case "NetGroup.Neighbor.Disconnect": 
					//Sent when a neighbor disconnects from this node. The info.neighbor:String property is the group address of the neighbor. The info.peerID:String property is the peer ID of the neighbor.
					break;
				case "NetGroup.Posting.Notify": 
					//Sent when a new Group Posting is received. The info.message:Object property is the message. The info.messageID:String property is this message's messageID.
					break;
				case "NetGroup.Replication.Fetch.Failed": 
					//Sent when a fetch request for an object (previously announced with NetGroup.Replication.Fetch.SendNotify) fails or is denied. A new attempt for the object will be made if it is still wanted. The info.index:Number property is the index of the object that had been requested.
					break;
				case "NetGroup.Replication.Fetch.Result": 
					//Sent when a fetch request was satisfied by a neighbor. The info.index:Number property is the object index of this result. The info.object:Object property is the value of this object. This index will automatically be removed from the Want set. If the object is invalid, this index can be re-added to the Want set with NetGroup.addWantObjects().
					break;
				case "NetGroup.Replication.Fetch.SendNotify": 
					//Sent when the Object Replication system is about to send a request for an object to a neighbor.The info.index:Number property is the index of the object that is being requested.
					break;
				case "NetGroup.Replication.Request": 
					//Sent when a neighbor has requested an object that this node has announced with NetGroup.addHaveObjects(). This request must eventually be answered with either NetGroup.writeRequestedObject() or NetGroup.denyRequestedObject(). Note that the answer may be asynchronous. The info.index:Number property is the index of the object that has been requested. The info.requestID:int property is the ID of this request, to be used by NetGroup.writeRequestedObject() or NetGroup.denyRequestedObject().
					break;
				case "NetGroup.SendTo.Notify": 
					//Sent when a message directed to this node is received. The info.message:Object property is the message. The info.from:String property is the groupAddress from which the message was received. The info.fromLocal:Boolean property is TRUE if the message was sent by this node (meaning the local node is the nearest to the destination group address), and FALSE if the message was received from a different node. To implement recursive routing, the message must be resent with NetGroup.sendToNearest() if info.fromLocal is FALSE.
					break;
				case "NetStream.Buffer.Empty": 
					//Flash Player is not receiving data quickly enough to fill the buffer. Data flow is interrupted until the buffer refills, at which time a NetStream.Buffer.Full message is sent and the stream begins playing again.
					break;
				case "NetStream.Buffer.Flush": 
					//Data has finished streaming, and the remaining buffer is emptied. Note: Not supported in AIR 3.0 for iOS.
					break;
				case "NetStream.Buffer.Full": 
					//The buffer is full and the stream begins playing.
					break;
				case "NetStream.Connect.Closed": 
					//The P2P connection was closed successfully. The info.stream property indicates which stream has closed. Note: Not supported in AIR 3.0 for iOS.
					mStreamPlaying = false;
					break;
				case "NetStream.Connect.Failed": 
					//The P2P connection attempt failed. The info.stream property indicates which stream has failed. Note: Not supported in AIR 3.0 for iOS.
					break;
				case "NetStream.Connect.Rejected": 
					//The P2P connection attempt did not have permission to access the other peer. The info.stream property indicates which stream was rejected. Note: Not supported in AIR 3.0 for iOS.
					break;
				case "NetStream.Connect.Success": 
					//The P2P connection attempt succeeded. The info.stream property indicates which stream has succeeded. Note: Not supported in AIR 3.0 for iOS.
					break;
				case "NetStream.DRM.UpdateNeeded": 
					//A NetStream object is attempting to play protected content, but the required Flash Access module is either not present, not permitted by the effective content policy, or not compatible with the current player. To update the module or player, use the update() method of flash.system.SystemUpdater. Note: Not supported in AIR 3.0 for iOS.
					break;
				case "NetStream.Failed": 
					//(Flash Media Server) An error has occurred for a reason other than those listed in other event codes.
					break;
				case "NetStream.MulticastStream.Reset": 
					//A multicast subscription has changed focus to a different stream published with the same name in the same group. Local overrides of multicast stream parameters are lost. Reapply the local overrides or the new stream's default parameters will be used.
					mStreamPlaying = true;
					break;
				case "NetStream.Pause.Notify": 
					//The stream is paused.
					mStreamPlaying = false;
					break;
				case "NetStream.Play.Failed": 
					//An error has occurred in playback for a reason other than those listed elsewhere in this table, such as the subscriber not having read access. Note: Not supported in AIR 3.0 for iOS.
					mStreamPlaying = false;
					break;
				case "NetStream.Play.FileStructureInvalid": 
					//(AIR and Flash Player 9.0.115.0) The application detects an invalid file structure and will not try to play this type of file. Note: Not supported in AIR 3.0 for iOS.
					break;
				case "NetStream.Play.InsufficientBW": 
					//(Flash Media Server) The client does not have sufficient bandwidth to play the data at normal speed. Note: Not supported in AIR 3.0 for iOS.
					break;
				case "NetStream.Play.NoSupportedTrackFound": 
					//(AIR and Flash Player 9.0.115.0) The application does not detect any supported tracks (video, audio or data) and will not try to play the file. Note: Not supported in AIR 3.0 for iOS.
					break;
				case "NetStream.Play.PublishNotify": 
					//The initial publish to a stream is sent to all subscribers.
					break;
				case "NetStream.Play.Reset": 
					//Caused by a play list reset. Note: Not supported in AIR 3.0 for iOS.
					break;
				case "NetStream.Play.Start": 
					//Playback has started.
					mStreamPlaying = true;
					break;
				case "NetStream.Play.Stop": 
					mStreamPlaying = false;
					//Playback has stopped.
					break;
				case "NetStream.Play.StreamNotFound": 
					//The file passed to the NetStream.play() method can't be found.
					mStreamPlaying = false;
					break;
				case "NetStream.Play.Transition": 
					//(Flash Media Server 3.5) The server received the command to transition to another stream as a result of bitrate stream switching. This code indicates a success status event for the NetStream.play2() call to initiate a stream switch. If the switch does not succeed, the server sends a NetStream.Play.Failed event instead. When the stream switch occurs, an onPlayStatus event with a code of "NetStream.Play.TransitionComplete" is dispatched. For Flash Player 10 and later. Note: Not supported in AIR 3.0 for iOS.
					break;
				case "NetStream.Play.UnpublishNotify": 
					//An unpublish from a stream is sent to all subscribers.
					break;
				case "NetStream.Publish.BadName": 
					//Attempt to publish a stream which is already being published by someone else.
					break;
				case "NetStream.Publish.Idle": 
					//The publisher of the stream is idle and not transmitting data.
					break;
				case "NetStream.Publish.Start": 
					//Publish was successful.
					break;
				case "NetStream.Record.AlreadyExists": 
					//The stream being recorded maps to a file that is already being recorded to by another stream. This can happen due to misconfigured virtual directories.
					break;
				case "NetStream.Record.Failed": 
					//An attempt to record a stream failed.
					break;
				case "NetStream.Record.NoAccess": 
					//Attempt to record a stream that is still playing or the client has no access right.
					break;
				case "NetStream.Record.Start": 
					//Recording has started.
					break;
				case "NetStream.Record.Stop": 
					//Recording stopped.
					break;
				case "NetStream.Seek.Complete": 
					//The seek fails, which happens if the stream is not seekable.
					mStartKeyframe = getNearestKeyframe();
					if (mAutoResumeAfterSeekComplete)
						mStream.resume();
					break;
				case "NetStream.Seek.Failed": 
					//The seek fails, which happens if the stream is not seekable.
					break;
				case "NetStream.Seek.InvalidTime": 
					//For video downloaded progressively, the user has tried to seek or play past the end of the video data that has downloaded thus far, or past the end of the video once the entire file has downloaded. The info.details property of the event object contains a time code that indicates the last valid position to which the user can seek.
					break;
				case "NetStream.Seek.Notify": 
					//The seek operation is complete. Sent when NetStream.seek() is called on a stream in AS3 NetStream Data Generation Mode. The info object is extended to include info.seekPoint which is the same value passed to NetStream.seek().
					mAutoResumeAfterSeekComplete = mStreamPlaying || currentFrame >= totalFrames - 1;
					if (mAutoResumeAfterSeekComplete)
						mStream.pause();
					break;
				case "NetStream.Step.Notify": 
					//The step operation is complete. Note: Not supported in AIR 3.0 for iOS.
					break;
				case "NetStream.Unpause.Notify": 
					//The stream is resumed.
					mStreamPlaying = true;
					break;
				case "NetStream.Unpublish.Success": 
					//The unpublish operation was successfuul.
					break;
				case "SharedObject.BadPersistence": 
					//A request was made for a shared object with persistence flags, but the request cannot be granted because the object has already been created with different flags.
					break;
				case "SharedObject.Flush.Failed": 
					//The "pending" status is resolved, but the SharedObject.flush() failed.
					break;
				case "SharedObject.Flush.Success": 
					//The "pending" status is resolved and the SharedObject.flush() call succeeded.
					break;
				case "SharedObject.UriMismatch": 
					//An attempt was made to connect to a NetConnection object that has a different URI (URL) than the shared object.
					break;
				case "NetStream.Video.DimensionChange": 
					//The video dimensions are available or have changed. Use the Video or StageVideo videoWidth/videoHeight property to query the new video dimensions. New in Flash Player 11.4/AIR 3.4.
					resizeVideo(mVideo.videoWidth, mVideo.videoHeight);
					break;
				default: 
					break;
			}
		}
		
		private function getNearestKeyframe():int
		{
			var idx:int = 0;
			var keytimes:Array = mMetaData.seekpoints;
			var second:Number = mStream.time;
			
			if (!keytimes || !keytimes.length)
			{
				return -1;
			}
			while (idx < keytimes.length && keytimes[idx].time < second)
			{
				++idx;
			}
			mDecodedFramesOffset = mStream.decodedFrames;
			mDroppedFramesOffset = mStream.info.droppedFrames;
			mCurrentFrame = mStartKeyframe + 1 + mStream.decodedFrames - mDecodedFramesOffset + mStream.info.droppedFrames - mDroppedFramesOffset;
			
			return mStream.time * mMetaData.videoframerate;
		}
		
		private function netStream_onMetaData(item:Object):void
		{
			mMetaData = item;
			mDecodedFrames = 0;
			mDecodedFramesOffset = 0;
			mDroppedFramesOffset = 0;
			mStartKeyframe = 0;
			disposeVideo();
			setupVideo(item.width, item.height);
			resizeVideo(mVideo.videoWidth, mVideo.videoHeight);
			onVideoChange();
		}
		
		private function netStream_onXMPMetaData(item:Object):void
		{
			netStream_onMetaData(item);
		}
		
		/** Adds or removes the EventListeners for drawing the texture. */
		private function onVideoChange():void
		{
			if (!mTexture)
				readjustSize();
			
			if (mActive && (mAddedToStage || mForceRecording))
			{
				mVideo.addEventListener(flash.events.Event.ENTER_FRAME, video_enterFrameHandler, false, 0, true);
			}
			else
			{
				mVideo.removeEventListener(flash.events.Event.ENTER_FRAME, video_enterFrameHandler);
			}
		}
		
		/** @inheritDoc */
		protected override function onVertexDataChanged():void
		{
			mVertexDataCacheInvalid = true;
		}
		
		/** Pauses the Video EventListeners (drawing/uploading) but the NetStream will not be affected.
		 *  @see start()
		 *  @see stop()
		 */
		public function pause():void
		{
			mRecording = false;
			onVideoChange();
		}
		
		/** Readjusts the dimensions of the video according to the current video/croppingFrame.
		 *  Further it resets drawnFrames, uploadedFrames as well as drawTime and uploadTime values.
		 */
		private function readjustSize(rectangle:Rectangle = null):void
		{
			if (!contextStatus)
				return;
			
			mStatsDrawnFrames = 0;
			mStatsUploadedFrames = 0;
			mStatsDrawTime = new Vector.<uint>();
			mStatsUploadTime = new Vector.<uint>();
			
			if (rectangle == null)
				rectangle = new Rectangle(0, 0, mVideo.width, mVideo.height);
			var newFrame:Rectangle = new Rectangle(rectangle.x, rectangle.y, Math.min(mVideo.width - rectangle.x, rectangle.width), Math.min(mVideo.height - rectangle.y, rectangle.height));
			if (!newFrame.equals(mFrame) || !mBitmapData)
			{
				if (mBitmapData)
					mBitmapData.dispose();
				mBitmapData = new BitmapData(newFrame.width, newFrame.height, mAlpha, 0);
				mBitmapData.lock();
				if (mTexture)
				{
					mTexture.dispose();
					mTexture = null;
				}
			}
			mFrame = newFrame;
			mFrameMatrix = new Matrix(1, 0, 0, 1, -mFrame.x, -mFrame.y);
			
			if (mVertexData)
			{
				mVertexData.setPosition(0, 0.0, 0.0);
				mVertexData.setPosition(1, mFrame.width, 0.0);
				mVertexData.setPosition(2, 0.0, mFrame.height);
				mVertexData.setPosition(3, mFrame.width, mFrame.height);
				onVertexDataChanged();
			}
			
			if (!texture)
				_texture = starling.textures.Texture.fromBitmapData(mBitmapData, false) as starling.textures.Texture;
			
			dispatchEventWith(starling.events.Event.RESIZE, false);
		}
		
		/**
		 * Stops the video recording if the instance is removed from the stage and autoStart true.
		 * @param	e
		 */
		private function removedFromStageHandler(e:starling.events.Event):void
		{
			mAddedToStage = false;
		}
		
		/** @inheritDoc */
		public override function render(support:RenderSupport, parentAlpha:Number):void
		{
			if (mTexture)
				support.batchQuad(this, parentAlpha, mTexture, mSmoothing);
		}
		
		/**
		 * Creates a new flash video object with given width/height.
		 * Call this method to synchronize video and texture size after assigning another video source,
		 * if the stream doesn't dispatch the meta data event or NetStream.Video.DimensionChange.
		 *
		 * @param	width
		 * @param	height
		 */
		public function resizeVideo(width:int = WIDTH, height:int = HEIGHT):void
		{
			if (width <= 0 || height <= 0)
				return;
			if (width != mVideo.width || height != mVideo.height || mFrame.width != mVideo.width || mFrame.height != mVideo.height)
			{
				disposeVideo();
				setupVideo(width, height)
				var rect:Rectangle = new Rectangle(0, 0, mVideo.width, mVideo.height);
				readjustSize(rect);
				onVideoChange();
			}
		}
		
		private function securityErrorHandler(event:SecurityErrorEvent):void
		{
			trace("securityErrorHandler: " + event);
		}
		
		private function setupVideo(width:int = WIDTH, height:int = HEIGHT):void
		{
			mVideo = new flash.media.Video(width, height);
			mVideo.attachNetStream(mStream);
		}
		
		/**
		 * Starting/Resuming the video.
		 * @param	forceRecording
		 * Starts the video recording, even if the Video has not been added to stage. E.g. to use the texture
		 * in multiple Images, a ParticleSystem, with a custom renderer or whatever, instead of the Video itself.
		 *  @see pause()
		 *  @see stop()
		 */
		public function start(forceRecording:Boolean = false):void
		{
			mActive = true;
			mRecording = true;
			mForceRecording = forceRecording;
			onVideoChange();
		}
		
		/** Stopping the video recording and EventListeners.
		 *  @see pause()
		 *  @see start()
		 */
		public function stop():void
		{
			mActive = false;
			mStreamPlaying = false;
			pause();
			if (mVideo)
				mVideo.attachNetStream(null);
		}
		
		/**
		 * Updates vertexData if flipped horizontally/vertically.
		 */
		private function updateVertexData():void
		{
			mVertexData.setTexCoords(0, mFlipHorizontal ? 1.0 : 0.0, mFlipVertical ? 1.0 : 0.0);
			mVertexData.setTexCoords(1, mFlipHorizontal ? 0.0 : 1.0, mFlipVertical ? 1.0 : 0.0);
			mVertexData.setTexCoords(2, mFlipHorizontal ? 1.0 : 0.0, mFlipVertical ? 0.0 : 1.0);
			mVertexData.setTexCoords(3, mFlipHorizontal ? 0.0 : 1.0, mFlipVertical ? 0.0 : 1.0);
			mVertexDataCacheInvalid = true;
		}
		
		/**
		 * Uploading the BitmapData to the Texture.
		 * @see Video
		 */
		public function upload():void
		{
			if (!contextStatus)
				return;
			
			if (!mTexture || !mBitmapData)
				return;
			
			mTime = getTimer();
			
			mTextureClass(mTexture.base).uploadFromBitmapData(mBitmapData);
			mStatsUploadTime.unshift(getTimer() - mTime);
			
			while (mStatsUploadTime.length > STATS_PRECISION)
				mStatsUploadTime.pop();
			++mStatsUploadedFrames;
			dispatchEventWith(de.flintfabrik.starling.events.VideoEvent.UPLOAD_COMPLETE);
		}
		
		/**
		 * Is called when a new frame is available.
		 * @param	e
		 */
		private function video_enterFrameHandler(e:flash.events.Event):void
		{
			if (!contextStatus)
				return;
			
			if (mStream.decodedFrames == 0 && mDecodedFrames != 0)
			{
				// if the stream is not playing and fps drop to 0, decodedFrames gets reset to 0 ... so we have to note that ourselves.
				mDecodedFramesOffset -= mDecodedFrames;
			}
			
			mDecodedFrames = mStream.decodedFrames;
			mCurrentFrame = mStartKeyframe + 1 + mStream.decodedFrames - mDecodedFramesOffset + mStream.info.droppedFrames - mDroppedFramesOffset;
			mNewFrameAvailable = mLastFrame != mCurrentFrame;
			
			if (mNewFrameAvailable)
			{
				dispatchEventWith(de.flintfabrik.starling.events.VideoEvent.VIDEO_FRAME);
				if (mRecording)
				{
					draw();
					upload();
				}
			}
		}
		
		/**
		 * The bitmapData with the video image.
		 * Do NOT change the reference or call dispose() on it!
		 */
		public function get bitmapData():BitmapData
		{
			return mBitmapData;
		}
		
		/**
		 * Returns a Boolean whether the context is available or not (e.g. disposed)
		 * @return
		 */
		private function get contextStatus():Boolean
		{
			if (!Starling.current.context || Starling.current.context.driverInfo == "Disposed")
			{
				mContextLost = true;
				mNewFrameAvailable = false;
				mAutoStartAfterHandledLostContext = isActive;
				pause();
				return false;
			}
			else if (Starling.current.context && Starling.current.context.driverInfo != "Disposed" && mContextLost)
			{
				mContextLost = false;
				return false;
			}
			return true;
		}
		
		/**
		 * The current frame of the Video, starting with 1
		 */
		
		public function get currentFrame():int
		{
			return mCurrentFrame;
		}
		
		/**
		 * Returns the average drawing time (up to 15 frames, if already available)
		 */
		public function get drawTime():Number
		{
			var res:Number = 0;
			var len:uint = mStatsDrawTime.length;
			for (var i:int = len - 1; i >= 0; --i)
			{
				res += mStatsDrawTime[i];
			}
			return res / len;
		}
		
		/**
		 * Returns the number of drawn frames since the last call of start(), stop(), pause() or readjustSize()
		 */
		public function get drawnFrames():uint
		{
			return mStatsDrawnFrames;
		}
		
		/**
		 * Returns whether the vertexData of the Video instance is flipped horizontally.
		 */
		public function get flipHorizontal():Boolean
		{
			return mFlipHorizontal;
		}
		
		/**
		 * Mirrors the video horizontally. This just changes the vertexData, neither bitmapData nor texture.
		 */
		public function set flipHorizontal(value:Boolean):void
		{
			mFlipHorizontal = value;
			updateVertexData();
		}
		
		/**
		 * Returns whether the vertexData of the Video instance is flipped vertically.
		 */
		public function get flipVertical():Boolean
		{
			return mFlipVertical;
		}
		
		/**
		 * Mirrors the video vertically. This just changes the vertexData, neither bitmapData nor texture.
		 */
		public function set flipVertical(value:Boolean):void
		{
			mFlipVertical = value;
			updateVertexData();
		}
		
		/** Returns whether the video is active.
		 *  Note: The video being active doesn't mean that it is recording. If you want to know whether the video
		 *  will be drawn and uploaded, use isRecording instead.
		 *  @see start()
		 */
		public function get isActive():Boolean
		{
			return mActive;
		}
		
		/** Returns whether the video is drawn and uploaded to texture or not.
		 *  Note: If the video is not on stage it will never be drawn to texturere regardless of it's active state.
		 *  Nevertheless it will start as soon as it is added to the stage if active is true.
		 *  @see start()
		 */
		public function get isRecording():Boolean
		{
			return mRecording || mForceRecording;
		}
		
		/**
		 * Returns the length of the Video according to it's metaData
		 */
		
		public function get length():Number
		{
			return mMetaData.duration;
		}
		
		/** Returns the metaData object of the NetStream
		 */
		public function get metaData():Object
		{
			return mMetaData;
		}
		
		/**
		 * Returns whether a new video frame is available but hasn't been drawn, yet.
		 */
		public function get newFrameAvailable():Boolean
		{
			return mNewFrameAvailable;
		}
		
		/**
		 * Returns the average upload time (up to 15 frames, if already available)
		 */
		public function get uploadTime():Number
		{
			var res:Number = 0;
			var len:uint = mStatsUploadTime.length;
			for (var i:int = len - 1; i >= 0; --i)
			{
				res += mStatsUploadTime[i];
			}
			return res / len;
		}
		
		/**
		 * Returns the number of uploaded frames since the last call of start(), stop(), pause() or readjustSize()
		 */
		public function get uploadedFrames():uint
		{
			return mStatsUploadedFrames;
		}
		
		/** The smoothing filter that is used for rendering the texture.
		 *   @default NONE
		 *   @see starling.textures.TextureSmoothing
		 */
		public function get smoothing():String
		{
			return mSmoothing;
		}
		
		public function set smoothing(value:String):void
		{
			if (TextureSmoothing.isValid(value))
				mSmoothing = value;
			else
				throw new ArgumentError("Invalid smoothing mode: " + value);
		}
		
		/** The texture with the video image. Can be used in other DisplayObjects then the Video as well.
		 *  Note: The texture will never be transformed by the use of flipHorizontal/flipVertical.
		 */
		public function get texture():starling.textures.Texture
		{
			return mTexture;
		}
		
		private function set _texture(value:starling.textures.Texture):void
		{
			if (value == null)
			{
				throw new ArgumentError("Texture cannot be null");
			}
			else if (value != mTexture)
			{
				if (mTexture)
					mTexture.dispose();
				mTexture = value;
				mTextureClass = Class(getDefinitionByName(getQualifiedClassName(mTexture.base)));
				mVertexData.setPremultipliedAlpha(mTexture.premultipliedAlpha);
				onVertexDataChanged();
			}
		}
		
		/**
		 * Current time of the playhead in the Video
		 */
		public function get time():Number
		{
			return mStream.time;
		}
		
		/**
		 * Estimated number of total frames in the video, according to it's metaData.
		 */
		public function get totalFrames():int
		{
			return mMetaData.duration * mMetaData.videoframerate;
		}
		
		/**
		 * The native flash video object to which the netStream is attached.
		 */
		public function get video():flash.media.Video
		{
			return mVideo;
		}
		
		public function set video(video:flash.media.Video):void
		{
			disposeVideo();
			
			mVideo = video;
			if (mActive && (mAddedToStage || mForceRecording))
				mVideo.addEventListener(flash.events.Event.ENTER_FRAME, video_enterFrameHandler, false, 0, true);
			
			readjustSize();
		}
	
	}

}
