package com.redfox.listenapp.ui.screen.video

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.redfox.listenapp.domain.model.AbSegment

class AbRepeatController {
    val segments = mutableStateListOf<AbSegment>()
    var activeSegmentIndex: Int? by mutableStateOf(null)
    var isAbMode: Boolean by mutableStateOf(false)
    var pendingAPos: Double? = null
    var light: String by mutableStateOf("")

    fun insertSegment(segment: AbSegment) {
        val index = segments.indexOfFirst { it.aPos > segment.aPos }
        if (index >= 0) segments.add(index, segment) else segments.add(segment)
    }

    fun getActiveSegment(): AbSegment? {
        return activeSegmentIndex?.let { segments.getOrNull(it) }
    }

    fun recordA(currentTime: Double): Boolean {
        if (light.isEmpty() && pendingAPos == null) {
            light = "a"
            pendingAPos = currentTime
            return true
        } else if (light == "a" && pendingAPos != null) {
            light = ""
            pendingAPos = null
            return true
        }
        return false
    }

    fun recordB(currentTime: Double): Boolean {
        if (pendingAPos != null && currentTime > pendingAPos!!) {
            light = ""
            val segment = AbSegment(aPos = pendingAPos!!, bPos = currentTime)
            insertSegment(segment)
            pendingAPos = null
            return true
        }
        return false
    }

    fun selectSegment(index: Int): AbSegment? {
        return if (index == activeSegmentIndex) {
            activeSegmentIndex = null
            null
        } else {
            activeSegmentIndex = index
            segments.getOrNull(index)
        }
    }

    fun removeSegment(index: Int) {
        if (index in segments.indices) {
            segments.removeAt(index)
            if (activeSegmentIndex == index) activeSegmentIndex = null
            else if (activeSegmentIndex != null && activeSegmentIndex!! > index) {
                activeSegmentIndex = activeSegmentIndex!! - 1
            }
        }
    }

    fun clear() {
        segments.clear()
        activeSegmentIndex = null
        pendingAPos = null
        light = ""
    }
}
