package com.redfox.listenapp.data.model

import com.google.gson.annotations.SerializedName

data class AbRecordSaveRequest(
    val curriculumId: Int,
    val recordPhase: List<AbSegmentDto>,
    val curriculumName: String,
    val category: Int
)

data class AbSegmentDto(
    val APos: Double,
    val BPos: Double
)
