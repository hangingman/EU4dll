module plugin.singleton;
import plugin.constant;


// mixinするとSingletonパターンが実装できる
// ref: http://www.codelogy.org/entry/2013/01/24/010106
mixin template singleton()
{
    static typeof(this) opCall()
    {
        static typeof(this) instance;
        if(!instance) instance = new typeof(this)();
        return instance;
    }
}
