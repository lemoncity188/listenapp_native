package com.redfox.listenapp.data.api

import com.redfox.listenapp.data.model.*
import retrofit2.http.Body
import retrofit2.http.POST

interface ApiService {

    // Auth
    @POST("user/login")
    suspend fun login(@Body request: LoginRequest): ApiResponse<String>

    @POST("user/register")
    suspend fun register(@Body request: RegisterRequest): ApiResponse<Any>

    @POST("user/sendCode")
    suspend fun sendCode(@Body request: SendCodeRequest): ApiResponse<Any>

    @POST("user/change/password")
    suspend fun changePassword(@Body request: ChangePasswordRequest): ApiResponse<Any>

    @POST("user/info")
    suspend fun getUserInfo(@Body request: EmptyRequest = EmptyRequest()): ApiResponse<UserInfo>

    @POST("user/logout")
    suspend fun logout(@Body request: EmptyRequest = EmptyRequest()): ApiResponse<Any>

    @POST("user/removal")
    suspend fun removal(@Body request: RemovalRequest): ApiResponse<Any>

    @POST("user/setting/vip")
    suspend fun setVip(@Body request: SetVipRequest): ApiResponse<Any>

    // Content
    @POST("dict/selectByKind")
    suspend fun selectByKind(@Body request: KindRequest): ApiResponse<List<CategoryDto>>

    @POST("category/selectByCategoryNo")
    suspend fun selectByCategoryNo(@Body request: CategoryQueryRequest): ApiResponse<List<CurriculumDto>>

    @POST("curriculum/selectByCategoryId")
    suspend fun selectByCategoryId(@Body request: CurriculumQueryRequest): ApiResponse<List<EpisodeDto>>

    @POST("curriculum/load")
    suspend fun loadCurriculum(@Body request: IdRequest): ApiResponse<CurriculumDetailDto>

    @POST("curriculumGoodUserRelated/thumbUp")
    suspend fun thumbUp(@Body request: ThumbUpRequest): ApiResponse<Any>

    @POST("curriculumScheduleUserRelated/collection")
    suspend fun collection(@Body request: CollectionRequest): ApiResponse<Any>

    // Records
    @POST("curriculumUserRecord/pageList")
    suspend fun getRecordPageList(@Body request: RecordQueryRequest): ApiResponse<RecordListDto>

    @POST("curriculumUserRecord/insertOrUpdate")
    suspend fun saveRecord(@Body request: AbRecordSaveRequest): ApiResponse<Any>

    @POST("curriculumUserRecord/deleteRecord")
    suspend fun deleteRecord(@Body request: RecordQueryRequest): ApiResponse<Any>

    @POST("curriculumUserDaydayuse/specialize")
    suspend fun specialize(@Body request: SpecializeRequest): ApiResponse<Any>

    // Study
    @POST("study/list")
    suspend fun getStudyList(@Body request: EmptyRequest = EmptyRequest()): ApiResponse<StudyListDto>

    // Suggestion
    @POST("suggest/insert")
    suspend fun submitSuggestion(@Body request: SuggestRequest): ApiResponse<Any>
}
