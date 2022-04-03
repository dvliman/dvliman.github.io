---
title: "Building a Live Streaming app in Clojure"
date: 2022-02-28T06:00:00Z
draft: false
---

I want to echo [John Carmack](https://twitter.com/ID_AA_Carmack)’s [tweet that all giant companies use open-source FFmpeg in the backends](https://twitter.com/ID_AA_Carmack/status/1258531455220609025). [FFmpeg](https://www.ffmpeg.org/) is a core piece of technology that powers our live-streaming and recording system at Inspire Fitness. It certainly is high-quality open-source software that we use to record and stream countless hours of workout videos.

It looks like this:
{{< figure width="296" height="640" src="https://raw.githubusercontent.com/dvliman/dvliman.github.io/master/resources/public/images/live-sessions.png" alt="live sessions" >}}
{{< figure width="296" height="640" src="https://raw.githubusercontent.com/dvliman/dvliman.github.io/master/resources/public/images/session-detail.png" alt="session detail" >}}


# Users can:
1.  watch live-streaming content, or
2.  playback on-demand videos from our content library

# High level

Behind the scene, we have:
1.  IP cameras are wired up in each studio room.
2.  The cameras support the RTSP protocol.
3.  A software pipeline integrated with our custom CMS to broadcast (stream) our cameras feed to the internet while simultaneously recording and storing the content to AWS S3 storage for on-demand playback.

# How it all works together:

1. We configure classes (the recordings) to start at a particular time in our dashboard. The time aligns with our studio schedules, where gym members would often join our classes to work out alongside the instructors.
2. We [kick off a dedicated ec2 instance with FFmpeg baked in an AMI image](https://docs.aws.amazon.com/cli/latest/reference/ec2/run-instances.html) when the class starts. We call this our encoder/transcoder.
{{< gist dvliman 2aa587f7b024615e4697da7b48a00120 >}}

3. As soon as the ec2 boots up, it runs the cloud-init script, which starts the Clojure process and [mount](https://github.com/tolitius/mount) (a state management library) that would then starts the dependencies:
{{< gist dvliman e4a63a35091e83ebae3d29d34ade450a >}}

4. This would in turn calls `start-stream`:
{{< gist dvliman 607974927b33b0e734de3704976bb32f >}}

5. The `start-stream` logic is actually pretty simple. It pulls feed from our camera and egress out our CDN partner
{{< gist dvliman e604c2981bfb691803d84bd0b4858e39 >}}
The output would be a playback URL that our video player would be pulling from.

Notice we are essentially invoking the FFmpeg that we bundled earlier to:

1.  take input from RTSP transport protocol
2.  [argument flags for the video/audio codec](https://www.ffmpeg.org/ffmpeg-formats.html)

| Flag | What it does |
|------|--------------|
| -re | read input at native frame rate. Mainly used to simulate a grab device i.e if you wanted to stream a video file, then you would want this, otherwise it might stream too fast |
| -c:a aac | transcode to AAC codec |
| -ar 48000 | set the audio sample rate |
| -b:a 128k | set the audio bitrate |
| -c:v h264 or copy | transcode to h264 codec or simply send the frame verbatim to output |
|-hls_time | the duration for video segment length |
| -f flv | says to deliver the output stream in an flv wrapper |
| rtmp:// | is where the transcoded video stream get pushed to |

The code is essentially a shell wrapper to FFmpeg command-line arguments. FFmpeg is the swiss-army tool for all video/audio codecs

The whole `encoder.clj` is about 300 lines long with error handling. It handles file uploads (video segment files, FFmpeg logs for debugging), egress to primary and secondary/fallback RTMP slot, shutdown processes, and the ec2 instance when we are done with the recording.

# Lesson learned

This was a rescue project from Go to Clojure. The previous architecture had too many moving pieces, making HTTP requests across multiple micro-services. The main server would crash daily due to improper handling of WebSocket messages, causing messages to be lost and encoder instances not starting up on time.

The rewrite reduced the complexities. [Simple Made Easy](https://www.youtube.com/watch?v=SxdOUGdseq4) as [Rich Hickey](https://clojure.org/about/history).

Rewriting a project is never a good approach considering the opportunity cost. I evaluated a few offerings: [mux.com](http://mux.com), Cloudflare Stream, Amazon IVS. On paper, they have all the building blocks we need. In addition, some have features like video analytics, policing/signing playback URL, which would be useful for us.

Ultimately, the fact that we still had 2 years contract with the CDN company was why we still manage our encoder.

In hindsight, if we consider the storage costs and S3 egress bandwidth fee on top of the CDN costs, I would probably go for ready-made solutions for our company stage. I would start optimizing when we have more traffic.

The good thing is that this system works really well for live-streaming workload with programmatic access. (Sidenote: barring occasional internet hiccups in our studio).

If you have a video production pipeline that involves heavy video editing, going with prebuilt software could be more flexible until you solidify the core functionalities.

# Special thanks to:
1.  [Daniel Fitzpatrick](https://github.com/crinklywrappr) and Vincent Ho. My coworkers helped proofread this article and maintain the broadcast system. I enjoy working with you both ❤️. We even have automated tests to prove the camera stream is working end to end!
2.  Neil, our product manager, understands tech trade-offs and works with me to balance the product roadmap.
3.  Daniel Glauser, who hired me for this Clojure gig


