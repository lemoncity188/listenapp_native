export interface User { name?: string; userId: number; username: string; vip: number; avatar?: string; }
export interface Category { id: number; code: string; desc: string; img?: string; }
export interface Course { id: number; curriculumName?: string; categoryName?: string; poster?: string; thumbnail?: string; url?: string; videoUrl?: string; categoryId?: number; thumbUp?: number; collection?: number; specialize?: number; curriculumDesc?: string; desc?: string; }
export interface Study { curriculumList?: Course[]; categoryList?: Course[]; }
export interface Segment { APos: number; BPos: number; }
export interface Records { recordPhase?: Segment[]; }
export class CategoryBody { categoryNo: string = ''; searchText: string = ''; categoryId: number = 0; }
export class KindBody { kind: string = 'video'; }
export class CategoryIDBody { categoryId: number = 0; }
export class IDBody { id: number = 0; }
export class CurriculumIDBody { curriculumId: number = 0; }
export class ThumbBody { curriculumId: number = 0; thumbUp: number = 1; }
export class CollectionBody { curriculumId: number = 0; collection: number = 1; }
export class SpecializeBody { curriculumId: number = 0; specialize: number = 1; }
export class SaveRecordsBody { curriculumId: number = 0; recordPhase: Segment[] = []; curriculumName: string = ''; category: number = 0; }
export class VIPBody { username: string = ''; }
export function courseTitle(course: Course): string { return course.curriculumName || course.categoryName || '课程'; }
export function boundedSeek(value: number, duration: number): number {
  if (!Number.isFinite(value)) { return 0; }
  return Math.max(0, Number.isFinite(duration) && duration > 0 ? Math.min(value, duration) : value);
}
export function validSegment(segment: Segment): boolean {
  return Number.isFinite(segment.APos) && Number.isFinite(segment.BPos) && segment.APos >= 0 && segment.BPos > segment.APos;
}
export function toggleActive(active: number, index: number, length: number): number {
  return index < 0 || index >= length ? active : active === index ? -1 : index;
}
export function activeAfterDelete(active: number, index: number): number { return active === index ? -1 : active > index ? active - 1 : active; }
