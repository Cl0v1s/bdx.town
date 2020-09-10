(window.webpackJsonp=window.webpackJsonp||[]).push([["chunk-commons"],{Kw8l:function(t,s,e){"use strict";var a=e("cRgN");e.n(a).a},cRgN:function(t,s,e){},ot3S:function(t,s,e){"use strict";var a=e("wd/R"),n=e.n(a),i={name:"Status",props:{account:{type:Object,required:!1,default:function(){return{}}},fetchStatusesByInstance:{type:Boolean,required:!1,default:!1},showCheckbox:{type:Boolean,required:!0,default:!1},status:{type:Object,required:!0},page:{type:Number,required:!1,default:0},userId:{type:String,required:!1,default:""},godmode:{type:Boolean,required:!1,default:!1}},data:function(){return{showHiddenStatus:!1}},methods:{capitalizeFirstLetter:function(t){return t.charAt(0).toUpperCase()+t.slice(1)},changeStatus:function(t,s,e){this.$store.dispatch("ChangeStatusScope",{statusId:t,isSensitive:s,visibility:e,reportCurrentPage:this.page,userId:this.userId,godmode:this.godmode,fetchStatusesByInstance:this.fetchStatusesByInstance})},deleteStatus:function(t){var s=this;this.$confirm("Are you sure you want to delete this status?","Warning",{confirmButtonText:"OK",cancelButtonText:"Cancel",type:"warning"}).then(function(){s.$store.dispatch("DeleteStatus",{statusId:t,reportCurrentPage:s.page,userId:s.userId,godmode:s.godmode,fetchStatusesByInstance:s.fetchStatusesByInstance}),s.$message({type:"success",message:"Delete completed"})}).catch(function(){s.$message({type:"info",message:"Delete canceled"})})},handleStatusSelection:function(t){this.$emit("status-selection",t)},handleRouteChange:function(){this.$router.push({name:"StatusShow",params:{id:this.status.id}})},optionPercent:function(t,s){var e=t.options.reduce(function(t,s){return t+s.votes_count},0);return 0===e?0:+(s.votes_count/e*100).toFixed(1)},parseTimestamp:function(t){return n()(t).format("YYYY-MM-DD HH:mm")},propertyExists:function(t,s,e){return e?t[s]&&t[e]:t[s]}}},o=(e("Kw8l"),e("KHd+")),r=Object(o.a)(i,function(){var t=this,s=t.$createElement,e=t._self._c||s;return t.status.deleted?e("el-card",{staticClass:"status-card"},[e("div",{attrs:{slot:"header"},slot:"header"},[e("div",{staticClass:"status-header"},[e("div",{staticClass:"status-account-container"},[e("div",{staticClass:"status-account"},[e("h4",{staticClass:"status-deleted"},[t._v(t._s(t.$t("reports.statusDeleted")))])])])])]),t._v(" "),e("div",{staticClass:"status-body"},[t.status.content?e("span",{staticClass:"status-content",domProps:{innerHTML:t._s(t.status.content)}}):e("span",{staticClass:"status-without-content"},[t._v("no content")])]),t._v(" "),e("div",{staticClass:"status-footer"},[t.status.created_at?e("span",{staticClass:"status-created-at"},[t._v(t._s(t.parseTimestamp(t.status.created_at)))]):t._e(),t._v(" "),t.status.url?e("a",{staticClass:"account",attrs:{href:t.status.url,target:"_blank"},on:{click:function(t){t.stopPropagation()}}},[t._v("\n      Open status in instance\n      "),e("i",{staticClass:"el-icon-top-right"})]):t._e()])]):e("el-card",{staticClass:"status-card",nativeOn:{click:function(s){return t.handleRouteChange()}}},[e("div",{attrs:{slot:"header"},slot:"header"},[e("div",{staticClass:"status-header"},[e("div",{staticClass:"status-account-container"},[e("div",{staticClass:"status-account"},[t.showCheckbox?e("el-checkbox",{staticClass:"status-checkbox",on:{change:function(s){return t.handleStatusSelection(t.account)}}}):t._e(),t._v(" "),t.propertyExists(t.account,"id")?e("router-link",{staticClass:"router-link",attrs:{to:{name:"UsersShow",params:{id:t.account.id}}},nativeOn:{click:function(t){t.stopPropagation()}}},[e("div",{staticClass:"status-card-header"},[t.propertyExists(t.account,"avatar")?e("img",{staticClass:"status-avatar-img",attrs:{src:t.account.avatar}}):t._e(),t._v(" "),t.propertyExists(t.account,"nickname")?e("span",{staticClass:"status-account-name"},[t._v(t._s(t.account.nickname))]):e("span",[t.propertyExists(t.account,"nickname")?e("span",{staticClass:"status-account-name"},[t._v("\n                  "+t._s(t.account.nickname)+"\n                ")]):e("span",{staticClass:"status-account-name deactivated"},[t._v("("+t._s(t.$t("users.invalidNickname"))+")")])])])]):t._e()],1)]),t._v(" "),e("div",{staticClass:"status-actions"},[e("div",{staticClass:"status-tags"},[t.status.sensitive?e("el-tag",{attrs:{type:"warning",size:"large"}},[t._v(t._s(t.$t("reports.sensitive")))]):t._e(),t._v(" "),e("el-tag",{attrs:{size:"large"}},[t._v(t._s(t.capitalizeFirstLetter(t.status.visibility)))])],1),t._v(" "),e("el-dropdown",{attrs:{trigger:"click"},nativeOn:{click:function(t){t.stopPropagation()}}},[e("el-button",{staticClass:"status-actions-button",attrs:{plain:"",size:"small",icon:"el-icon-edit"}},[t._v("\n            "+t._s(t.$t("reports.changeScope"))),e("i",{staticClass:"el-icon-arrow-down el-icon--right"})]),t._v(" "),e("el-dropdown-menu",{attrs:{slot:"dropdown"},slot:"dropdown"},[t.status.sensitive?t._e():e("el-dropdown-item",{nativeOn:{click:function(s){return t.changeStatus(t.status.id,!0,t.status.visibility)}}},[t._v("\n              "+t._s(t.$t("reports.addSensitive"))+"\n            ")]),t._v(" "),t.status.sensitive?e("el-dropdown-item",{nativeOn:{click:function(s){return t.changeStatus(t.status.id,!1,t.status.visibility)}}},[t._v("\n              "+t._s(t.$t("reports.removeSensitive"))+"\n            ")]):t._e(),t._v(" "),"public"!==t.status.visibility?e("el-dropdown-item",{nativeOn:{click:function(s){return t.changeStatus(t.status.id,t.status.sensitive,"public")}}},[t._v("\n              "+t._s(t.$t("reports.public"))+"\n            ")]):t._e(),t._v(" "),"private"!==t.status.visibility?e("el-dropdown-item",{nativeOn:{click:function(s){return t.changeStatus(t.status.id,t.status.sensitive,"private")}}},[t._v("\n              "+t._s(t.$t("reports.private"))+"\n            ")]):t._e(),t._v(" "),"unlisted"!==t.status.visibility?e("el-dropdown-item",{nativeOn:{click:function(s){return t.changeStatus(t.status.id,t.status.sensitive,"unlisted")}}},[t._v("\n              "+t._s(t.$t("reports.unlisted"))+"\n            ")]):t._e(),t._v(" "),e("el-dropdown-item",{nativeOn:{click:function(s){return t.deleteStatus(t.status.id)}}},[t._v("\n              "+t._s(t.$t("reports.deleteStatus"))+"\n            ")])],1)],1)],1)])]),t._v(" "),e("div",{staticClass:"status-body"},[t.status.spoiler_text?e("div",[e("strong",[t._v(t._s(t.status.spoiler_text))]),t._v(" "),t.showHiddenStatus?t._e():e("el-button",{staticClass:"show-more-button",attrs:{size:"mini"},on:{click:function(s){t.showHiddenStatus=!0}}},[t._v("Show more")]),t._v(" "),t.showHiddenStatus?e("el-button",{staticClass:"show-more-button",attrs:{size:"mini"},on:{click:function(s){t.showHiddenStatus=!1}}},[t._v("Show less")]):t._e(),t._v(" "),t.showHiddenStatus?e("div",[e("span",{staticClass:"status-content",domProps:{innerHTML:t._s(t.status.content)}}),t._v(" "),t.status.poll?e("div",{staticClass:"poll"},[e("ul",t._l(t.status.poll.options,function(s,a){return e("li",{key:a},[t._v("\n              "+t._s(s.title)+"\n              "),e("el-progress",{attrs:{percentage:t.optionPercent(t.status.poll,s)}})],1)}),0)]):t._e(),t._v(" "),t._l(t.status.media_attachments,function(t,s){return e("div",{key:s,staticClass:"image"},[e("img",{attrs:{src:t.preview_url}})])})],2):t._e()],1):t._e(),t._v(" "),t.status.spoiler_text?t._e():e("div",[e("span",{staticClass:"status-content",domProps:{innerHTML:t._s(t.status.content)}}),t._v(" "),t.status.poll?e("div",{staticClass:"poll"},[e("ul",t._l(t.status.poll.options,function(s,a){return e("li",{key:a},[t._v("\n            "+t._s(s.title)+"\n            "),e("el-progress",{attrs:{percentage:t.optionPercent(t.status.poll,s)}})],1)}),0)]):t._e(),t._v(" "),t._l(t.status.media_attachments,function(t,s){return e("div",{key:s,staticClass:"image"},[e("img",{attrs:{src:t.preview_url}})])})],2),t._v(" "),e("div",{staticClass:"status-footer"},[e("span",{staticClass:"status-created-at"},[t._v(t._s(t.parseTimestamp(t.status.created_at)))]),t._v(" "),t.status.url?e("a",{staticClass:"account",attrs:{href:t.status.url,target:"_blank"},on:{click:function(t){t.stopPropagation()}}},[t._v("\n        "+t._s(t.$t("statuses.openStatusInInstance"))+"\n        "),e("i",{staticClass:"el-icon-top-right"})]):t._e()])])])},[],!1,null,null,null);r.options.__file="index.vue";s.a=r.exports},rIUS:function(t,s,e){"use strict";var a=e("o0o1"),n=e.n(a),i=e("yXPU"),o=e.n(i),r=e("mSNy"),c={name:"RebootButton",computed:{needReboot:function(){return this.$store.state.app.needReboot}},methods:{restartApp:function(){var t=o()(n.a.mark(function t(){return n.a.wrap(function(t){for(;;)switch(t.prev=t.next){case 0:return t.prev=0,t.next=3,this.$store.dispatch("RestartApplication");case 3:t.next=8;break;case 5:return t.prev=5,t.t0=t.catch(0),t.abrupt("return");case 8:this.$message({type:"success",message:r.a.t("settings.restartSuccess")});case 9:case"end":return t.stop()}},t,this,[[0,5]])}));return function(){return t.apply(this,arguments)}}()}},u=e("KHd+"),l=Object(u.a)(c,function(){var t=this.$createElement,s=this._self._c||t;return this.needReboot?s("el-tooltip",{attrs:{content:this.$t("settings.restartApp"),placement:"bottom-end"}},[s("el-button",{staticClass:"reboot-button",attrs:{type:"warning"},on:{click:this.restartApp}},[s("span",[s("i",{staticClass:"el-icon-refresh"}),this._v("\n      "+this._s(this.$t("settings.instanceReboot"))+"\n    ")])])],1):this._e()},[],!1,null,null,null);l.options.__file="index.vue";s.a=l.exports}}]);
//# sourceMappingURL=chunk-commons.51fe2926.js.map