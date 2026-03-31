/// Apple Health / Health Connect에서 가져온 유산소 행은 이 접두사로 `cardio_name`에 표시한다.
/// 동기화 시 같은 기간의 이 접두사 행만 삭제 후 재삽입한다.
const String kHealthSyncCardioPrefix = 'HealthSync|';
