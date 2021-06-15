# Photographic History

## About

This project was created during the Showpad WWDC21 Hackathon on the 14th of june of 2021.

The basic idea is that people are taking more and more photos, but we usually don't do much with them, and once we die, they're probably lost forever.

Wouldn't it be cool if we could create a map with a photographic history of the world?

Of course, privacy is a concern, but AI is getting better and better at classifying images, so it should be possible to filter out images without a lot of effort.

## Implementation

I used PhotoKit to get a list of albums from the iOS photo library and presented them in a list.

Once you open an album, the original image files are fetched (from the network if needed) using PhotoKit and analysed using the Vision framework.

Photos are displayed in a grid view using a Diffable Data Source, which we hadn't been able to use yet because of our iOS 12 support.

After a photo is analysed, the classification is used to determine if a photo can be made public.

Photos should:
- have a location
- be taken outdoors
- NOT contain people
- NOT be documents

This turned an album about a trip throug the South of France into a map of pictures of the environment, without privacy risks.

## Potential improvements

I tried allowing photos that contained people but no faces, using `VNDetectFaceRectanglesRequest`, but unfortunately that request wasn't able to detect faces that were partially in a photo, but still recognisable.

iOS 15 has better face detection, so maybe it's still possible to implement a filter like that.
