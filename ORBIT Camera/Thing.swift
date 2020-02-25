//
//  Thing.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 25/02/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

///  Abstract: the representation of a 'thing', the basic data type of the ORBIT Dataset.

import Foundation

/// A 'thing' that is important to a visually impaired person, and for a which a phone might be useful as a tool to pick it out of a scene.
/// For the ORBIT Dataset, to train and test computer vision / machine learning algorithms, this becomes a label – "what is it" – and set of videos – "this is what it looks like".
struct Thing {
    /// The label the participant gives it. This may contain personally identifying information.
    var labelParticipant: String
    /// The label used in the ORBIT Dataset. This is assigned by the research team. Goals: anonymised, regularised across dataset.
    var labelDataset: String?
    
    /// URLs to videos the participant has recorded of the thing, following the ORBIT procedure for capturing 'training' data.
    /// e.g. Blank background, rotate [around] the thing
    var videosTrain: [URL]
    /// URLs to videos the participant has recorded of the thing, following the ORBIT procedure for capturing 'test' data.
    /// e.g. Film the thing 'in the wild'. The more locations (and their differing backgrounds) the better.
    var videosTest: [URL]
    
    /// Initialises a new thing, with the information we have at the time: what the participant calls it.
    ///
    /// Parameter label: The label the participant wants to give the thing.
    init(withLabel label: String) {
        self.labelParticipant = label
        self.labelDataset = nil
        self.videosTrain = []
        self.videosTest = []
    }
}
