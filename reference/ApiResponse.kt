package com.redfox.listenapp.data.model

import com.google.gson.annotations.SerializedName

data class ApiResponse<T>(
    @SerializedName("status") val status: Int = -1,
    @SerializedName("data") val data: T? = null,
    @SerializedName("subMessage") val subMessage: String? = null,
    @SerializedName("errorCode") val errorCode: Int? = null,
    @SerializedName("subCode") val subCode: Int? = null
) {
    fun isSuccess(): Boolean = status == 0
}
