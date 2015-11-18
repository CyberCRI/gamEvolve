if(!internal) {
    if (!me || me.id != this.ownerId && !me.isAdmin) {
        cancel('Only owner or admin can edit game');
    }
    
    protect("playCount");
    protect("forkCount");
    protect("versionCount");
    protect("likeCount");
    protect("lastVersionId");
    protect("mixedFromGameIds");
    protect("mixedToGameIds");
    protect("screenshot");
    protect("animation");
    protect("description");
}
    
protect("ownerId");
protect("parentId");
protect("createdTime");

this.lastUpdatedTime = new Date().toISOString();
